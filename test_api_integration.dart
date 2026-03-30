// API 集成测试示例
// 这个文件展示了如何在实际应用中集成API客户端

import 'package:flutter/material.dart';
import 'package:teacher_schedule_app/services/api/index.dart';

/// API 集成使用示例
class ApiIntegrationExample extends StatefulWidget {
  const ApiIntegrationExample({Key? key}) : super(key: key);

  @override
  _ApiIntegrationExampleState createState() => _ApiIntegrationExampleState();
}

class _ApiIntegrationExampleState extends State<ApiIntegrationExample> {
  final ApiServiceManager _apiManager = ApiServiceManager();
  bool _isLoading = false;
  String _status = '未初始化';
  List<Course> _courses = [];
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    setState(() {
      _isLoading = true;
      _status = '初始化API...';
    });

    try {
      await _apiManager.initialize(
        baseUrl: 'http://localhost:5000', // 本地模拟服务器
        // 生产环境：'https://api.zhengfang.edu.cn'
      );

      setState(() {
        _status = 'API初始化成功';
        _currentUser = _apiManager.currentUser;
      });
    } catch (e) {
      setState(() {
        _status = 'API初始化失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _status = '正在登录...';
    });

    final loginRequest = LoginRequest(
      username: 'lisijie', // 教师工号或用户名
      password: 'password123', // 实际应用中应从安全存储获取
      userType: 'teacher',
    );

    final response = await _apiManager.login(loginRequest);

    setState(() {
      _isLoading = false;
      if (response.success) {
        _status = '登录成功: ${response.data?.displayName}';
        _currentUser = _apiManager.currentUser;
      } else {
        _status = '登录失败: ${response.error}';
      }
    });
  }

  Future<void> _fetchSchedule() async {
    if (!_apiManager.isLoggedIn) {
      setState(() {
        _status = '请先登录';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '获取课表...';
    });

    final response = await _apiManager.getTeacherSchedule();

    setState(() {
      _isLoading = false;
      if (response.success) {
        _courses = response.data ?? [];
        _status = '获取到 ${_courses.length} 门课程';
      } else {
        _status = '获取课表失败: ${response.error}';
        _courses = [];
      }
    });
  }

  Future<void> _testHealthCheck() async {
    setState(() {
      _isLoading = true;
      _status = '检查健康状态...';
    });

    final response = await _apiManager.healthCheck();

    setState(() {
      _isLoading = false;
      if (response.success) {
        _status = 'API连接正常: ${response.data}';
      } else {
        _status = 'API连接失败: ${response.error}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 集成测试'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态显示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _isLoading
                            ? const CircularProgressIndicator()
                            : Icon(
                                _status.contains('成功') || _status.contains('正常')
                                    ? Icons.check_circle
                                    : _status.contains('失败')
                                        ? Icons.error
                                        : Icons.info,
                                color: _status.contains('成功') || _status.contains('正常')
                                    ? Colors.green
                                    : _status.contains('失败')
                                        ? Colors.red
                                        : Colors.blue,
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentUser != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '当前用户: ${_currentUser!.realName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    if (_apiManager.isLoggedIn) ...[
                      const SizedBox(height: 8),
                      Chip(
                        label: const Text('已登录'),
                        backgroundColor: Colors.green.shade100,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 按钮组
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testHealthCheck,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('健康检查'),
                ),
                ElevatedButton.icon(
                  onPressed: _apiManager.isLoggedIn ? null : _testLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('模拟登录'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _apiManager.isLoggedIn ? _fetchSchedule : null,
                  icon: const Icon(Icons.schedule),
                  label: const Text('获取课表'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 课程列表
            if (_courses.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '课程列表 (${_courses.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _courses.length,
                            itemBuilder: (context, index) {
                              final course = _courses[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    '${course.weekDay}',
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                                title: Text(course.courseName),
                                subtitle: Text(
                                  '${course.weekDayString} ${course.timeString} | ${course.fullLocation}',
                                ),
                                trailing: Chip(
                                  label: Text('${course.credit}学分'),
                                  backgroundColor: Colors.blue.shade50,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}