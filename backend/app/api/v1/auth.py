from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.exc import IntegrityError
from jose import jwt, JWTError

from app.api import deps
from app.core import security
from app.core.config import settings
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse, AuthResponse, TokenResponse

router = APIRouter()

from app.models.finance import MST_Account

async def seed_default_user_coa(db: AsyncSession, user_id):
    # Fetch system template accounts (created_by == None)
    result = await db.execute(select(MST_Account).where(MST_Account.created_by == None).order_by(MST_Account.account))
    templates = result.scalars().all()
    
    new_accounts = []
    for t in templates:
        new_accounts.append(MST_Account(
            account=t.account,
            description=t.description,
            type=t.type,
            dimensi1=t.dimensi1,
            dimensi2=t.dimensi2,
            dimensi3=t.dimensi3,
            dimensi4=t.dimensi4,
            active=t.active,
            created_by=user_id
        ))
    if new_accounts:
        db.add_all(new_accounts)
        await db.commit()

@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(user_in: UserCreate, db: AsyncSession = Depends(deps.get_db)):
    # Check if email exists
    result = await db.execute(select(User).where(User.email == user_in.email))
    if result.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email sudah terdaftar."
        )
    
    hashed_password = security.get_password_hash(user_in.password)
    db_user = User(
        email=user_in.email,
        password_hash=hashed_password,
        full_name=user_in.full_name,
        base_currency=user_in.base_currency,
    )
    
    db.add(db_user)
    try:
        await db.commit()
        await db.refresh(db_user)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Database integrity error.")
        
    await seed_default_user_coa(db, db_user.id)
    
    access_token = security.create_access_token(subject=db_user.id)
    refresh_token = security.create_refresh_token(subject=db_user.id)
    
    user_resp = UserResponse.from_orm(db_user)
    
    return AuthResponse(
        success=True,
        message="Registrasi berhasil.",
        data={
            "user": user_resp.dict(),
            "tokens": {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
            }
        }
    )

@router.post("/login", response_model=AuthResponse)
async def login(user_in: UserLogin, db: AsyncSession = Depends(deps.get_db)):
    result = await db.execute(select(User).where(User.email == user_in.email))
    user = result.scalars().first()
    
    if not user or not security.verify_password(user_in.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email atau password salah."
        )
        
    user.last_login_at = datetime.utcnow()
    await db.commit()
    await db.refresh(user)
    
    access_token = security.create_access_token(subject=user.id)
    refresh_token = security.create_refresh_token(subject=user.id)
    
    return AuthResponse(
        success=True,
        message="Login berhasil.",
        data={
            "user": UserResponse.from_orm(user).dict(),
            "tokens": {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
            }
        }
    )

@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(refresh_token: str, db: AsyncSession = Depends(deps.get_db)):
    try:
        payload = security.decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type.")
        user_id = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token kedaluwarsa atau tidak valid.")
        
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=401, detail="User tidak ditemukan.")
        
    access_token = security.create_access_token(subject=user.id)
    return AuthResponse(
        success=True,
        message="Token refreshed.",
        data={
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }
    )

@router.get("/me", response_model=AuthResponse)
async def get_me(current_user: User = Depends(deps.get_current_user)):
    return AuthResponse(
        success=True,
        message="Profil user",
        data={"user": UserResponse.from_orm(current_user).dict()}
    )
