from database.connection import DatabaseConnection

class DashboardModule:
    def __init__(self, db: DatabaseConnection):
        self.db = db

    def get_statistics(self):
        tickets_count = self.db.fetch_data("SELECT COUNT(*) as count FROM tickets")[0]['count']
        open_tickets = self.db.fetch_data("SELECT COUNT(*) as count FROM tickets WHERE status = 'Açık'")[0]['count']
        inventory_count = self.db.fetch_data("SELECT COUNT(*) as count FROM inventory")[0]['count']

        return {
            "total_tickets": tickets_count,
            "open_tickets": open_tickets,
            "total_inventory": inventory_count
        }
