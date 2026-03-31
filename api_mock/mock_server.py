#!/usr/bin/env python3
"""完整 API 模拟服务器 - 通用演示"""

from flask import Flask, jsonify, request
from datetime import datetime

app = Flask(__name__)

MOCK_USER = {
    "teacher_id": "demo001",
    "name": "演示教师",
    "department": "通用院系",
    "university": "示例学校",
}

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    username = data.get('username', '')
    password = data.get('password', '')

    if username and password:
        return jsonify({
            'code': 0,
            'message': '登录成功',
            'data': {
                'token': 'mock_token_789',
                'user': MOCK_USER,
            }
        })
    return jsonify({'code': 1, 'message': '登录失败'})

@app.route('/api/schedule/weekly', methods=['GET'])
def weekly_schedule():
    return jsonify({'code': 0, 'data': []})

@app.route('/api/user/info', methods=['GET'])
def user_info():
    return jsonify({'code': 0, 'data': MOCK_USER})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
