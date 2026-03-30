#!/usr/bin/env python3
"""
简易的API模拟服务器
用于本地开发和测试
"""

import json
import random
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timedelta

class SimpleAPIHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()
    
    def do_OPTIONS(self):
        self._set_headers(200)
    
    def do_GET(self):
        if self.path == '/api/health':
            self._set_headers(200)
            response = {
                'healthy': True,
                'message': 'API服务器正常运行',
                'timestamp': datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response).encode())
        
        elif self.path == '/api/teacher/schedule':
            self._set_headers(200)
            response = {
                'success': True,
                'schedule': self._generate_courses(),
                'message': '获取课表成功',
                'timestamp': datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response).encode())
        
        else:
            self._set_headers(404)
            response = {'error': '接口不存在'}
            self.wfile.write(json.dumps(response).encode())
    
    def do_POST(self):
        if self.path == '/api/auth/login':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            
            username = data.get('username', '')
            password = data.get('password', '')
            
            # 简单的模拟认证
            if username == 'lisijie' and password in ['demo123', 'password123']:
                token = f"mock_token_{random.randint(10000, 99999)}"
                expires_at = datetime.now() + timedelta(hours=2)
                
                response = {
                    'success': True,
                    'token': token,
                    'userId': 'LSJ2026',
                    'username': '李思杰',
                    'userRole': 'teacher',
                    'expiresAt': expires_at.isoformat(),
                    'message': '登录成功'
                }
                self._set_headers(200)
            else:
                response = {
                    'success': False,
                    'error': '用户名或密码错误',
                    'message': '认证失败'
                }
                self._set_headers(401)
            
            self.wfile.write(json.dumps(response).encode())
        
        else:
            self._set_headers(404)
            response = {'error': '接口不存在'}
            self.wfile.write(json.dumps(response).encode())
    
    def _generate_courses(self):
        """生成模拟课程数据"""
        courses = []
        
        # 周一课程
        courses.append({
            'id': 'COURSE001',
            'courseId': 'DM101',
            'courseName': '数字合成技术（AE）',
            'courseType': '专业必修',
            'teacherId': 'LSJ2026',
            'teacherName': '李思杰',
            'weekDay': 1,
            'weekNum': 5,
            'periodStart': 5,
            'periodEnd': 6,
            'building': '信息楼',
            'classroom': '502教室',
            'credit': 3,
            'studentCount': 45,
        })
        
        # 周二课程
        courses.append({
            'id': 'COURSE002',
            'courseId': 'DM202',
            'courseName': '数字调色（达芬奇）',
            'courseType': '专业必修',
            'teacherId': 'LSJ2026',
            'teacherName': '李思杰',
            'weekDay': 2,
            'weekNum': 6,
            'periodStart': 3,
            'periodEnd': 4,
            'building': '艺术楼',
            'classroom': '309实验室',
            'credit': 3,
            'studentCount': 38,
        })
        
        # 周四课程
        courses.append({
            'id': 'COURSE003',
            'courseId': 'DM303',
            'courseName': '影视综合创作',
            'courseType': '专业选修',
            'teacherId': 'LSJ2026',
            'teacherName': '李思杰',
            'weekDay': 4,
            'weekNum': 4,
            'periodStart': 1,
            'periodEnd': 2,
            'building': '综合楼',
            'classroom': '101教室',
            'credit': 2,
            'studentCount': 32,
        })
        
        return courses
    
    def log_message(self, format, *args):
        # 减少日志输出
        pass

def run_server(port=5000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, SimpleAPIHandler)
    print(f'简易API服务器启动在 http://localhost:{port}')
    print('支持端点:')
    print('  GET  /api/health')
    print('  GET  /api/teacher/schedule')
    print('  POST /api/auth/login (用户名: lisijie, 密码: demo123)')
    print('按 Ctrl+C 停止服务器')
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\n服务器停止')
        httpd.server_close()

if __name__ == '__main__':
    run_server()