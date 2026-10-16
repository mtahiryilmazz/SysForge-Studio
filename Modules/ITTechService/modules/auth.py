from database.connection import DatabaseConnection
from database.logger import write_log

class AuthModule:
    def __init__(self, db: DatabaseConnection):
        self.db = db

    def login(self, username, password):
        query = "SELECT * FROM users WHERE username = ? COLLATE NOCASE AND password = ?"
        result = self.db.fetch_data(query, (username, password))
        if result:
            user_data = dict(result[0])
            write_log(self.db, username, "GİRİŞ", f"Kullanıcı girişi başarılı: {username}")
            return user_data
        return None

    def get_all_users(self):
        query = "SELECT * FROM users"
        return self.db.fetch_data(query)

    def add_user(self, username, password, role, permissions='*'):
        query = "INSERT INTO users (username, password, role, permissions) VALUES (?, ?, ?, ?)"
        return self.db.execute_query(query, (username, password, role, permissions))
        
    def update_user_permissions(self, user_id, permissions):
        query = "UPDATE users SET permissions = ? WHERE id = ?"
        return self.db.execute_query(query, (permissions, user_id))

    def update_last_active(self, user_id):
        import time
        timestamp = str(int(time.time()))
        query = "UPDATE users SET last_active = ? WHERE id = ?"
        return self.db.execute_query(query, (timestamp, user_id))

    def get_active_users(self):
        import time
        current_time = int(time.time())
        query = "SELECT * FROM users WHERE last_active IS NOT NULL"
        all_users = self.db.fetch_data(query)
        active_users = []
        for dict_u in all_users:
            u = dict(dict_u)
            la = str(u.get('last_active') or '')
            if la:
                ts = la.split('|')[0] if '|' in la else la
                if ts.isdigit():
                    if current_time - int(ts) <= 300: # 5 Dakika
                        active_users.append(u)
        return active_users

    def update_user_password(self, user_id, new_password):
        query = "UPDATE users SET password = ? WHERE id = ?"
        return self.db.execute_query(query, (new_password, user_id))

    def update_username(self, user_id, new_username):
        try:
            query = "UPDATE users SET username = ? WHERE id = ?"
            return self.db.execute_query(query, (new_username, user_id))
        except:
            return False
        
    def delete_user(self, user_id):
        query = "DELETE FROM users WHERE id = ?"
        return self.db.execute_query(query, (user_id,))

