#!/usr/bin/env python3
from flask import Flask, jsonify
import psycopg2
from datetime import datetime
import os

app = Flask(__name__)

# Database connection details
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_NAME = os.environ.get('DB_NAME', 'testdb')
DB_USER = os.environ.get('DB_USER', 'testuser')
DB_PASS = os.environ.get('DB_PASS', 'testpass')

def get_db_connection():
    """Try to connect to PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        return conn
    except Exception as e:
        return None

@app.route('/')
def home():
    """Homepage"""
    return jsonify({
        'service': 'Python test Application',
        'message': 'Hello from Ibrahim!',
        'timestamp': datetime.now().isoformat(),
        'status': 'running'
    })

@app.route('/health')
def health():
    """Health check endpoint - checks database connectivity"""
    # Check database connection
    conn = get_db_connection()
    
    if conn:
        try:
            # Try a simple query
            cur = conn.cursor()
            cur.execute('SELECT version();')
            db_version = cur.fetchone()[0]
            cur.close()
            conn.close()
            
            return jsonify({
                'status': 'healthy',
                'database': 'connected',
                'db_version': db_version.split()[0:2],
                'timestamp': datetime.now().isoformat()
            }), 200
        except Exception as e:
            return jsonify({
                'status': 'degraded',
                'database': 'error',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }), 500
    else:
        return jsonify({
            'status': 'unhealthy',
            'database': 'disconnected',
            'timestamp': datetime.now().isoformat()
        }), 503

@app.route('/info')
def info():
    """Show application information"""
    return jsonify({
        'python_version': '3.12.3',
        'flask_version': 'installed',
        'database_host': DB_HOST,
        'database_name': DB_NAME,
        'endpoints': [
            '/ - Homepage',
            '/health - Health check',
            '/info - This page'
        ]
    })

if __name__ == '__main__':
    print(f"Starting Flask app...")
    print(f"Database: {DB_USER}@{DB_HOST}/{DB_NAME}")
    app.run(host='0.0.0.0', port=5000, debug=True)
