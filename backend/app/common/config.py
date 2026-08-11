"""Environment-driven application settings."""

from functools import lru_cache
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", ".env.local"),
        extra="ignore",
        case_sensitive=True,
        enable_decoding=False,
    )

    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""
    DATABASE_URL: str = "sqlite:///./arenahub.db"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    BACKEND_HOST: str = "127.0.0.1"
    BACKEND_PORT: int = 8000
    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    ADMIN_EMAILS: list[str] = []
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CLIENT_EMAIL: str = ""
    FIREBASE_PRIVATE_KEY: str = ""
    ADMOB_ANDROID_APP_ID: str = ""
    ADMOB_IOS_APP_ID: str = ""
    ADMOB_ANDROID_REWARDED_AD_UNIT_ID: str = ""
    ADMOB_IOS_REWARDED_AD_UNIT_ID: str = ""
    ADMOB_SSV_PUBLIC_KEYS_URL: str = "https://www.gstatic.com/admob/reward/verifier-keys.json"
    ADMOB_SSV_SECRET: str = ""

    @field_validator("CORS_ORIGINS", "ADMIN_EMAILS", mode="before")
    @classmethod
    def split_csv(cls, value):
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
