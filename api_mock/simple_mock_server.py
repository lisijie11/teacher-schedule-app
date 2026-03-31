#!/usr/bin/env python3
"""简易 API 模拟服务器 - 通用演示用"""

from flask import Flask, jsonify, request

app = Flask(__name__)

# 默认用户数据（演示用）
MOCK_USER = {
    'userId': 'demo001',
    'username': '演示用户',
    'role': '教师',
}

MOCK_COURSES = [
    {
        'courseId': 'demo001',
        'courseName': '示例课程A',
        'location': '教学楼101',
        'teacher': '教师A',
        'dayOfWeek': 1,
        'startSection': 1,
        'endSection': 2,
        'weekType': 'all',
        'color': '#4A90D9',
    },
    {
        'courseId': 'demo002',
        'courseName': '示例课程B',
        'location': '教学楼202',
        'teacher': '教师B',
        'dayOfWeek': 3,
        'startSection': 3,
        'endSection': 4,
        'weekType': 'odd',
        'color': '#50C878',
    },
]

@app.route('/api/auth/login', methods=['POST'])
def login():
    """登录接口"""
    data = request.get_json() or {}
    username = data.get('username', '')
    password = data.get('password', '')

    if username and password:
        return jsonify({
            'code': 0,
            'message': '登录成功',
            'data': {
                'token': 'mock_token_123456',
                'user': MOCK_USER.copy(),
            }
        })
    return jsonify({'code': 1, 'message': '用户名或密码错误'})

@app.route('/api/schedule/weekly', methods=['GET'])
def get_weekly_schedule():
    """获取周课表"""
    return jsonify({
        'code': 0,
        'data': MOCK_COURSES,
    })

@app.route('/api/user/info', methods=['GET'])
def get_user_info():
    """获取用户信息"""
    return jsonify({
        'code': 0,
        'data': MOCK_USER,
    })

if __name__ == '__main__':
    print('启动 API 模拟服务器...')
    print('  POST /api/auth/login (用户名: demo, 密码: demo123)')
    print('  GET  /api/schedule/weekly')
    print('  GET  /api/user/info')
    print('')
    app.run(host='0.0.0.0', port=5000, debug=True)
