#!/usr/bin/env python3
"""
测试Mock API的客户端脚本
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:5000"

def test_health_check():
    """测试健康检查接口"""
    print("=== 测试健康检查接口 ===")
    try:
        response = requests.get(f"{BASE_URL}/api/system/health", timeout=5)
        print(f"状态码: {response.status_code}")
        print(f"响应: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
        print()
        return response.status_code == 200
    except requests.exceptions.ConnectionError:
        print("错误: 无法连接到API服务，请确保服务已启动")
        print("运行命令: python mock_server.py")
        print()
        return False

def test_teacher_info():
    """测试教师信息接口"""
    print("=== 测试教师信息接口 ===")
    response = requests.get(f"{BASE_URL}/api/teacher/info")
    print(f"状态码: {response.status_code}")
    data = response.json()
    print(f"教师ID: {data.get('teacher_id')}")
    print(f"姓名: {data.get('name')}")
    print(f"学院: {data.get('department')}")
    print()

def test_teacher_courses():
    """测试课程列表接口"""
    print("=== 测试课程列表接口 ===")
    response = requests.get(f"{BASE_URL}/api/teacher/courses")
    data = response.json()
    print(f"学期: {data.get('semester')}")
    print(f"课程总数: {data.get('total')}")
    print("\n课程列表:")
    for i, course in enumerate(data.get('courses', []), 1):
        print(f"{i}. [{course['course_code']}] {course['course_name']}")
        print(f"   学分: {course['credits']}, 课时: {course['hours_per_week']}, 教室: {course['classroom']}")
    print()

def test_weekly_schedule():
    """测试周课表接口"""
    print("=== 测试周课表接口 ===")
    response = requests.get(f"{BASE_URL}/api/schedule/weekly?teacher_id=LSJ2024")
    data = response.json()
    print(f"教师ID: {data.get('teacher_id')}")
    print(f"最后更新: {data.get('last_updated')}")
    print(f"时间段数: {len(data.get('periods', []))}")
    
    print("\n工作日课程安排:")
    weekday_count = [0] * 7
    for course in data.get('weekday_schedule', []):
        weekday_count[course['day'] - 1] += 1
    
    days = ['一', '二', '三', '四', '五', '六', '日']
    for i, count in enumerate(weekday_count):
        if count > 0:
            print(f"周{days[i]}: {count}节课")
    
    print(f"\n汕尾校区周末课程: {len(data.get('weekend_schedule', []))}节")
    print()

def test_daily_schedule():
    """测试日课表接口"""
    print("=== 测试日课表接口 ===")
    today = datetime.now().strftime("%Y-%m-%d")
    response = requests.get(f"{BASE_URL}/api/schedule/daily?date={today}")
    data = response.json()
    
    print(f"日期: {data.get('date')}")
    print(f"星期: {data.get('day_of_week')}")
    print(f"总课程数: {data.get('total_courses')}")
    print(f"总课时: {data.get('total_hours')}")
    
    courses = data.get('courses', [])
    if courses:
        print("\n今日课程:")
        for i, course in enumerate(courses, 1):
            period_info = f"第{course['period']+1}节 ({course.get('start', 'N/A')}-{course.get('end', 'N/A')})"
            print(f"{i}. {period_info} - {course['course_name']}")
            print(f"   教室: {course['classroom']}")
    else:
        print("\n今日无课程安排")
    print()

def test_tasks():
    """测试任务接口"""
    print("=== 测试任务接口 ===")
    response = requests.get(f"{BASE_URL}/api/tasks")
    data = response.json()
    
    print(f"任务总数: {data.get('total')}")
    
    tasks = data.get('tasks', [])
    if tasks:
        print("\n近期任务:")
        for i, task in enumerate(tasks[:5], 1):  # 只显示前5个
            print(f"{i}. [{task['type']}] {task['title']}")
            print(f"   截止: {task['due_date']}, 优先级: {task['priority']}, 状态: {task['status']}")
            print(f"   预估时间: {task['estimated_hours']}小时")
    print()

def test_available_classrooms():
    """测试可用教室接口"""
    print("=== 测试可用教室接口 ===")
    today = datetime.now().strftime("%Y-%m-%d")
    response = requests.get(f"{BASE_URL}/api/classrooms/available?date={today}")
    data = response.json()
    
    print(f"查询日期: {data.get('date')}")
    print(f"可用教室总数: {data.get('total_available')}")
    
    classrooms = data.get('classrooms', [])
    if classrooms:
        print("\n可用教室列表:")
        for i, room in enumerate(classrooms, 1):
            print(f"{i}. {room['building']}-{room['room_id']}")
            print(f"   类型: {room['type']}, 容量: {room['capacity']}人")
    print()

def main():
    """主测试函数"""
    print("教师教务系统Mock API测试客户端")
    print("=" * 50)
    
    # 首先检查服务是否可用
    if not test_health_check():
        return
    
    # 测试各个接口
    try:
        test_teacher_info()
        test_teacher_courses()
        test_weekly_schedule()
        test_daily_schedule()
        test_tasks()
        test_available_classrooms()
        
        print("=" * 50)
        print("所有接口测试完成！")
        print("Mock API服务正常运行中...")
        
    except Exception as e:
        print(f"测试过程中出错: {e}")

if __name__ == '__main__':
    main()