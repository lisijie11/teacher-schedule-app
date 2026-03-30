import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../services/api/index.dart';
import '../services/widget_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({Key? key, this.onLoginSuccess}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String _errorMessage = '';

  late ApiServiceManager _apiManager;

  @override
  void initState() {
    super.initState();
    _apiManager = ApiServiceManager();
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    try {
      // 初始化API管理器，使用本地模拟服务器地址
      // 如果没有本地服务器，则使用离线模式
      await _apiManager.initialize(
        baseUrl: 'http://127.0.0.1:5000', // 本地测试地址
      );

      // 检查API连接
      final healthResponse = await _apiManager.healthCheck();
      if (!healthResponse.success) {
        print('API服务器连接失败，使用离线模式');
        // 在离线模式下，仍然可以登录（使用本地存储的演示账号）
      }

      // 如果已有认证信息，自动跳转
      if (_apiManager.isLoggedIn) {
        _navigateToMainApp();
      }
    } catch (e) {
      print('API初始化失败，使用离线模式: $e');
      // 初始化失败不影响演示登录
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // 演示账号登录（离线模式）
      if (username == 'lisijie' && password == 'demo123') {
        _offlineLogin(username);
        return;
      }

      // API在线登录
      final loginRequest = LoginRequest(
        username: username,
        password: password,
        userType: 'teacher',
      );

      final response = await _apiManager.login(loginRequest);

      if (response.success) {
        _navigateToMainApp();
      } else {
        setState(() {
          _errorMessage = response.error ?? '登录失败，请检查用户名和密码';
          _isLoading = false;
        });
      }
    } catch (e) {
      // API连接失败时，使用演示账号
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      
      if (username == 'lisijie' && password == 'demo123') {
        _offlineLogin(username);
      } else {
        setState(() {
          _errorMessage = '网络连接失败，请检查网络设置或使用演示账号登录 (lisijie / demo123)';
          _isLoading = false;
        });
        print('登录异常: $e');
      }
    }
  }

  void _offlineLogin(String username) {
    // 离线模式下的登录
    print('离线模式登录: $username');
    
    // 在本地存储中设置演示登录状态
    _saveOfflineAuth(username);
    
    // 跳转到主界面
    _navigateToMainApp();
  }

  Future<void> _saveOfflineAuth(String username) async {
    final box = await Hive.openBox('api_auth');
    final expiresAt = DateTime.now().add(const Duration(hours: 2));
    
    await box.putAll({
      'token': 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
      'userId': 'LSJ2026',
      'username': username,
      'expiresAt': expiresAt.toIso8601String(),
      'userRole': 'teacher',
      'offlineMode': true,
    });
  }

  void _navigateToMainApp() async {
    // 更新小组件数据
    try {
      // 获取用户信息
      final box = await Hive.openBox('api_auth');
      final username = box.get('username', defaultValue: '李思杰');
      final userId = box.get('userId', defaultValue: 'LSJ2026');
      final userRole = box.get('userRole', defaultValue: '教师');
      
      // 更新小组件，传递用户信息
      await WidgetService.updateWidgetWithUserInfo(
        userName: username,
        facultyName: userId == 'LSJ2026' ? '数字媒体与设计学院' : null,
      );
    } catch (e) {
      // 小组件更新失败不影响主流程
      print('小组件更新失败: $e');
    }

    // 通知父组件登录成功
    widget.onLoginSuccess?.call();
    
    // 注意：现在AppWrapper会自动处理页面跳转
    // 所以我们只需关闭当前页面
    Navigator.of(context).pop();
  }

  void _testDemoLogin() async {
    setState(() {
      _usernameController.text = 'lisijie';
      _passwordController.text = 'demo123';
      _isLoading = true;
      _errorMessage = '';
    });

    // 直接使用离线模式登录
    _offlineLogin('lisijie');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // 背景装饰
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.withOpacity(0.15),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.1),
                    Colors.purple.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),

                  // Logo和标题
                  Hero(
                    tag: 'app-logo',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 标题
                  Text(
                    '教师课表助手',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '广东东软学院专用',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.lightText,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // 登录表单
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 用户名输入
                        TextFormField(
                          controller: _usernameController,
                          style: TextStyle(
                            color: AppTheme.whiteText,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 20,
                            ),
                            filled: true,
                            fillColor: AppTheme.cardColor,
                            hintText: '请输入教师工号或用户名',
                            hintStyle: TextStyle(
                              color: AppTheme.lightText.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.person,
                              color: AppTheme.lightText,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入用户名';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // 密码输入
                        TextFormField(
                          controller: _passwordController,
                          style: TextStyle(
                            color: AppTheme.whiteText,
                            fontSize: 16,
                          ),
                          obscureText: !_passwordVisible,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 20,
                            ),
                            filled: true,
                            fillColor: AppTheme.cardColor,
                            hintText: '请输入密码',
                            hintStyle: TextStyle(
                              color: AppTheme.lightText.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: AppTheme.lightText,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: AppTheme.lightText,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            if (value.length < 6) {
                              return '密码至少6位';
                            }
                            return null;
                          },
                        ),

                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // 登录按钮
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            shadowColor: Colors.deepPurple.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('登录系统'),
                        ),

                        const SizedBox(height: 16),

                        // 演示登录按钮
                        ElevatedButton(
                          onPressed: _isLoading ? null : _testDemoLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text('演示登录（测试用）'),
                        ),

                        const SizedBox(height: 24),

                        // 版本信息
                        Center(
                          child: Text(
                            '版本 2.0.0 • 广东东软学院数字媒体与设计学院',
                            style: TextStyle(
                              color: AppTheme.lightText.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class HomePageWrapper extends StatelessWidget {
  const HomePageWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教师课表助手'),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // 用户信息
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 登出逻辑
              final box = await Hive.openBox('api_auth');
              await box.clear();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎信息
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryDark.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '李思杰 老师',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.whiteText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '数字媒体与设计学院 • 广东东软学院',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.lightText,
                          ),
                        ),
                        Text(
                          '离线模式 • 演示数据',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 功能卡片网格
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  icon: Icons.today,
                  title: '今日课程',
                  description: '查看今天的课程安排',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                ),
                _buildFeatureCard(
                  icon: Icons.schedule,
                  title: '课程表',
                  description: '完整周课表视图',
                  color: Colors.green,
                ),
                _buildFeatureCard(
                  icon: Icons.checklist,
                  title: '任务清单',
                  description: '待办事项管理',
                  color: Colors.orange,
                ),
                _buildFeatureCard(
                  icon: Icons.settings,
                  title: '系统设置',
                  description: '偏好设置和管理',
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // API连接状态
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前为离线演示模式。如需连接学校教务系统，请联系管理员配置API服务。',
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.whiteText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}