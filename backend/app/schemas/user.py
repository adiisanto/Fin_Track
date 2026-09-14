import uuid
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=8)
    base_currency: str = Field(default="IDR", min_length=3, max_length=3)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: uuid.UUID
    full_name: str
    email: EmailStr
    base_currency: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int

class AuthResponse(BaseModel):
    success: bool
    message: str
    data: dict
