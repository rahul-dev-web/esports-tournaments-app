"""
SQLAlchemy ORM Models
- Replace Pydantic models for database
- Persistent storage
"""

from sqlalchemy import Column, String, Integer, DateTime, Boolean, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from enum import Enum

from app.core.database import Base

# Enums
class RoleEnum(str, Enum):
    user = "user"
    admin = "admin"

class TournamentStatusEnum(str, Enum):
    draft = "draft"
    published = "published"
    closed = "closed"

class RegistrationStatusEnum(str, Enum):
    pending = "pending"
    ad_verification = "ad_verification"
    registered = "registered"
    rejected = "rejected"

class RegistrationPolicyEnum(str, Enum):
    individual_ads = "individual_ads"
    captain_ads = "captain_ads"

# Database Models

class User(Base):
    """User model - database table"""
    __tablename__ = "users"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    google_id = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    username = Column(String, unique=True, index=True)
    bio = Column(Text, nullable=True)
    country = Column(String, nullable=True)
    state = Column(String, nullable=True)
    city = Column(String, nullable=True)
    photo_url = Column(String, nullable=True)
    preferred_game = Column(String, nullable=True)
    role = Column(SQLEnum(RoleEnum), default=RoleEnum.user)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    teams = relationship("Team", back_populates="captain")
    registrations = relationship("Registration", back_populates="user")

class Team(Base):
    """Team model - database table"""
    __tablename__ = "teams"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, index=True)
    game = Column(String)
    logo_url = Column(String, nullable=True)
    captain_id = Column(String, ForeignKey("users.id"))
    is_private = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    captain = relationship("User", back_populates="teams")
    members = relationship("TeamMember", back_populates="team")
    registrations = relationship("Registration", back_populates="team")

    @property
    def member_ids(self):
        return [member.user_id for member in self.members]

class TeamMember(Base):
    """Team member mapping"""
    __tablename__ = "team_members"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    team_id = Column(String, ForeignKey("teams.id"))
    user_id = Column(String, ForeignKey("users.id"))
    joined_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    team = relationship("Team", back_populates="members")

class Tournament(Base):
    """Tournament model - database table"""
    __tablename__ = "tournaments"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, index=True)
    game = Column(String)
    mode = Column(String)  # solo, duo, squad
    starts_at = Column(DateTime)
    entry_requirement = Column(String, nullable=True)
    reward = Column(String, nullable=True)
    total_slots = Column(Integer)
    registered_teams = Column(Integer, default=0)
    ads_required = Column(Integer, default=1)
    policy = Column(SQLEnum(RegistrationPolicyEnum), default=RegistrationPolicyEnum.individual_ads)
    status = Column(SQLEnum(TournamentStatusEnum), default=TournamentStatusEnum.draft)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    registrations = relationship("Registration", back_populates="tournament")

class Registration(Base):
    """Tournament registration"""
    __tablename__ = "registrations"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tournament_id = Column(String, ForeignKey("tournaments.id"))
    team_id = Column(String, ForeignKey("teams.id"))
    user_id = Column(String, ForeignKey("users.id"))
    status = Column(SQLEnum(RegistrationStatusEnum), default=RegistrationStatusEnum.pending)
    ads_required = Column(Integer)
    ads_completed = Column(Integer, default=0)
    completed_by = Column(String, nullable=True)  # JSON list of user IDs
    slot_assigned = Column(Boolean, default=False)
    slot_number = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    tournament = relationship("Tournament", back_populates="registrations")
    team = relationship("Team", back_populates="registrations")
    user = relationship("User", back_populates="registrations")
