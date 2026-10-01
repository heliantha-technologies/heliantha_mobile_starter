import logging
from functools import lru_cache
from pathlib import Path

from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]

INSECURE_JWT_PLACEHOLDERS = {
    "",
    "change_me",
    "change_me_with_a_long_random_secret",
    "secret",
    "jwt_secret",
    "your_secret_here",
}


class Settings(BaseSettings):
    app_name: str = "Heliantha Mobile API"
    app_env: str = "development"
    api_prefix: str = "/v1"






    prestashop_base_url: str = "https://heliantha.ma"
    prestashop_webservice_key: str = ""
    prestashop_language_id: int = 3
    prestashop_timeout_seconds: float = 20.0

    jwt_secret: str = "CHANGE_ME"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 720

    mobile_bridge_url: str = ""
    mobile_bridge_secret: str = ""
    checkout_write_enabled: bool = False

    notifications_db_path: str = Field(
        default="./heliantha_notifications.sqlite3",
        validation_alias=AliasChoices(
            "NOTIFICATIONS_DB_PATH",
            "NOTIFICATION_DB_PATH",
            "notifications_db_path",
            "notification_db_path",
        ),
    )
    firebase_project_id: str = ""
    google_application_credentials: str = ""
    notification_webhook_secret: str = ""
    internal_cache_clear_token: str = Field(
        default="",
        validation_alias=AliasChoices(
            "INTERNAL_CACHE_CLEAR_TOKEN",
            "CACHE_CLEAR_TOKEN",
            "internal_cache_clear_token",
            "cache_clear_token",
        ),
    )

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def resolved_notification_db_path(self) -> Path:
        raw = (self.notifications_db_path or "").strip()
        p = Path(raw) if raw else Path("./heliantha_notifications.sqlite3")
        if not p.is_absolute():
            return (BACKEND_DIR / p).resolve()
        return p.resolve()

    @property
    def notification_db_path(self) -> str:
        return str(self.resolved_notification_db_path)

    @property
    def cors_origin_list(self) -> list[str]:
        raw_list = [x.strip() for x in self.cors_origins.split(",") if x.strip()]
        is_prod = self.app_env.strip().lower() in {"production", "prod"}
        if not is_prod:
            dev_defaults = [
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:8000",
                "http://127.0.0.1:8000",
                "http://localhost:8080",
                "http://127.0.0.1:8080",
            ]
            for origin in dev_defaults:
                if origin not in raw_list:
                    raw_list.append(origin)
        return [origin for origin in raw_list if origin != "*"]

    @model_validator(mode="after")
    def validate_security_settings(self) -> "Settings":
        secret = (self.jwt_secret or "").strip()
        is_prod = self.app_env.strip().lower() in {"production", "prod"}
        is_placeholder = (
            secret.lower() in INSECURE_JWT_PLACEHOLDERS
            or "change_me" in secret.lower()
        )

        if is_prod:
            if not secret:
                raise ValueError(
                    "Configuration invalide en production : JWT_SECRET est obligatoire."
                )
            if is_placeholder:
                raise ValueError(
                    "Configuration invalide en production : JWT_SECRET ne peut pas être une valeur par défaut ou un placeholder."
                )
            if len(secret) < 32:
                raise ValueError(
                    "Configuration invalide en production : JWT_SECRET trop faible (minimum 32 caractères requis)."
                )
        else:
            if not secret or is_placeholder or len(secret) < 32:
                logging.getLogger("app.core.config").warning(
                    "AVERTISSEMENT SÉCURITÉ : JWT_SECRET faible ou par défaut utilisé en environnement de développement. "
                    "Définissez une clé sécurisée pour la production."
                )

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
