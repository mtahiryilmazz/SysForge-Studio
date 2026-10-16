from database.connection import DatabaseConnection
from datetime import datetime

class TicketsModule:
    def __init__(self, db: DatabaseConnection):
        self.db = db

    def create_ticket(self, department, personnel, internal_num, issue_type, priority, description):
        date_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        query = """
            INSERT INTO tickets (department, personnel_name, internal_number, issue_type, priority, description, date, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'Açık')
        """
        return self.db.execute_query(query, (department, personnel, internal_num, issue_type, priority, description, date_str))

    def get_all_tickets(self):
        query = "SELECT * FROM tickets ORDER BY id DESC"
        return [dict(row) for row in self.db.fetch_data(query)]
    def update_status(self, ticket_id, new_status):
        query = "UPDATE tickets SET status = ? WHERE id = ?"
        return self.db.execute_query(query, (new_status, ticket_id))

    def close_with_reply(self, ticket_id, reply_text):
        query_sel = "SELECT description FROM tickets WHERE id = ?"
        res = self.db.fetch_data(query_sel, (ticket_id,))
        if res:
            old_desc = res[0]['description']
            date_str = datetime.now().strftime("%Y-%m-%d %H:%M")
            new_desc = f"{old_desc}\n\n[Çözüm - {date_str}]: {reply_text}"
            query_upd = "UPDATE tickets SET description = ?, status = 'Kapalı' WHERE id = ?"
            return self.db.execute_query(query_upd, (new_desc, ticket_id))
        return False
