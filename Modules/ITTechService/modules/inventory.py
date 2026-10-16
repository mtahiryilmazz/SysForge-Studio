from database.connection import DatabaseConnection

class InventoryModule:
    def __init__(self, db: DatabaseConnection):
        self.db = db

    def add_device(self, brand, model, serial_no, ip_address, location, user_name):
        import uuid
        if not serial_no or serial_no == "-":
            serial_no = f"TEMP-{uuid.uuid4().hex[:8]}"
            
        query = """
            INSERT INTO inventory (brand, model, serial_no, ip_address, location, user_name)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        return self.db.execute_query(query, (brand, model, serial_no, ip_address, location, user_name))

    def get_all_devices(self):
        query = "SELECT * FROM inventory ORDER BY id DESC"
        return [dict(row) for row in self.db.fetch_data(query)]
