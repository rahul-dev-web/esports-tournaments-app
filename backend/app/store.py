from uuid import uuid4
from .common.models import UserProfile, Team, Tournament, Registration


class Store:
    users: dict[str, UserProfile] = {}
    teams: dict[str, Team] = {}
    tournaments: dict[str, Tournament] = {}
    registrations: dict[str, Registration] = {}

    @staticmethod
    def new_id() -> str:
        return str(uuid4())


store = Store()
