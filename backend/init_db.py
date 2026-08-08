"""
Initialize database with sample data
- Create tables
- Add sample users, teams, tournaments
"""

from app.core.database import engine, Base, SessionLocal
from app.core.models import User, Team, TeamMember, Tournament, RoleEnum, TournamentStatusEnum, RegistrationPolicyEnum
from datetime import datetime, timedelta
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def init_database():
    """Create tables and sample data"""
    
    # Create tables
    logger.info("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    logger.info("✅ Tables created")
    
    db = SessionLocal()
    
    try:
        # Add sample users
        logger.info("Adding sample users...")
        
        users = [
            User(
                id="user-1",
                google_id="google-1",
                email="player1@example.com",
                name="Player One",
                username="player1",
                role=RoleEnum.user
            ),
            User(
                id="user-2",
                google_id="google-2",
                email="player2@example.com",
                name="Player Two",
                username="player2",
                role=RoleEnum.user
            ),
            User(
                id="admin-1",
                google_id="admin-google",
                email="admin@example.com",
                name="Admin User",
                username="admin",
                role=RoleEnum.admin
            ),
        ]
        
        for user in users:
            if not db.query(User).filter(User.id == user.id).first():
                db.add(user)
        
        db.commit()
        logger.info("✅ Users added")
        
        # Add sample teams
        logger.info("Adding sample teams...")
        
        team = Team(
            id="team-1",
            name="Team Alpha",
            game="BGMI",
            captain_id="user-1",
            is_private=False
        )
        
        if not db.query(Team).filter(Team.id == team.id).first():
            db.add(team)
            db.commit()
            
            # Add members
            members = [
                TeamMember(team_id="team-1", user_id="user-1"),
                TeamMember(team_id="team-1", user_id="user-2"),
            ]
            
            for member in members:
                db.add(member)
            
            db.commit()
            logger.info("✅ Teams added")
        
        # Add sample tournaments
        logger.info("Adding sample tournaments...")
        
        tournament = Tournament(
            id="tournament-1",
            name="Summer Championship",
            game="BGMI",
            mode="squad",
            starts_at=datetime.utcnow() + timedelta(days=7),
            reward="10000 INR",
            total_slots=16,
            ads_required=4,
            policy=RegistrationPolicyEnum.individual_ads,
            status=TournamentStatusEnum.published
        )
        
        if not db.query(Tournament).filter(Tournament.id == tournament.id).first():
            db.add(tournament)
            db.commit()
            logger.info("✅ Tournaments added")
        
        logger.info("✅ Database initialization complete!")
        
    except Exception as e:
        logger.error(f"❌ Error initializing database: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_database()