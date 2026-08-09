"""Application configuration."""

from pydantic_settings import BaseSettings, SettingsConfigDict
import os


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env.local", extra="ignore")
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./arenahub.db")

    # Server
    BACKEND_HOST: str = "localhost"
    BACKEND_PORT: int = 8000

    # Environment
    ENVIRONMENT: str = "development"

settings = Settings()
