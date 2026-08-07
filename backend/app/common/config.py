from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_jwt_secret: str = ""
    admin_emails: str = ""
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def admins(self) -> set[str]:
        return {email.strip().lower() for email in self.admin_emails.split(",") if email.strip()}


@lru_cache
def get_settings() -> Settings:
    return Settings()
