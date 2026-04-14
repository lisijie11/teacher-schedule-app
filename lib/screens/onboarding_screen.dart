import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme.dart';

/// 首次使用引导页面
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 引导数据
  String _userName = '';
  DateTime _semesterStart = DateTime(DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1, 9, 1);
  int _totalWeeks = 20;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final settings = Hive.box('settings');

    // 保存用户设置
    if (_userName.isNotEmpty) {
      await settings.put('userName', _userName);
    }
    await settings.put('semesterStartDate', _semesterStart.toIso8601String().split('T')[0]);
    await settings.put('totalWeeks', _totalWeeks);

    // 标记首次引导完成
    await settings.put('firstLaunchDone', true);

    // 关闭引导页面（通过返回到首页）
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg1 : AppTheme.lightBg0,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部进度指示器
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppTheme.primaryDark
                            : (isDark ? AppTheme.darkBg3 : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // 跳过按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  '跳过',
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            // 页面内容
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildWelcomePage(theme, isDark),
                  _buildNamePage(theme, isDark),
                  _buildSemesterPage(theme, isDark),
                  _buildSchedulePage(theme, isDark),
                  _buildCompletePage(theme, isDark),
                ],
              ),
            ),

            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        child: const Text('上一步'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _currentPage == 4 ? _completeOnboarding : _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_currentPage == 4 ? '开始使用' : '下一步'),
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

  /// 第1页：欢迎页
  Widget _buildWelcomePage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryDark,
                  AppTheme.primaryDark.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryDark.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            '欢迎使用\n教师课表助手',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '专为教师设计的课程管理应用\n让课表管理更简单、更高效',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          _buildFeatureItem(
            icon: Icons.dashboard_customize_rounded,
            title: '多视图课表',
            description: '周视图、日视图、列表视图自由切换',
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.widgets_rounded,
            title: '桌面小组件',
            description: '随时查看今日课程和进度',
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.notifications_active_rounded,
            title: '智能提醒',
            description: '上课前自动提醒，不错过任何课程',
            theme: theme,
          ),
        ],
      ),
    );
  }

  /// 第2页：设置姓名
  Widget _buildNamePage(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primaryDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '设置您的姓名',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '方便在通知和小组件中识别',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            onChanged: (value) => _userName = value,
            decoration: InputDecoration(
              hintText: '请输入您的姓名',
              prefixIcon: const Icon(Icons.badge_outlined),
              filled: true,
              fillColor: isDark ? AppTheme.darkBg2 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryDark, width: 2),
              ),
            ),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBg2 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.textTheme.bodySmall?.color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '姓名将显示在课表通知和小组件中',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 第3页：设置学期
  Widget _buildSemesterPage(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppTheme.primaryDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '设置学期信息',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '帮助计算当前是第几周',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 32),

          // 学期起始日
          Text(
            '学期起始日',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _semesterStart,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: AppTheme.primaryDark,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() => _semesterStart = date);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBg2 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_semesterStart.year}年${_semesterStart.month}月${_semesterStart.day}日',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 学期总周数
          Text(
            '学期总周数',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBg2 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('周数'),
                    Text(
                      '$_totalWeeks 周',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _totalWeeks.toDouble(),
                  min: 10,
                  max: 25,
                  divisions: 15,
                  activeColor: AppTheme.primaryDark,
                  onChanged: (value) {
                    setState(() => _totalWeeks = value.round());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('10周', style: theme.textTheme.bodySmall),
                    Text('25周', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 第4页：作息时间
  Widget _buildSchedulePage(ThemeData theme, bool isDark) {
    // 默认作息时间
    const weekdaySchedule = [
      {'name': '第1-2节', 'time': '08:30 - 10:05'},
      {'name': '第3-4节', 'time': '10:25 - 12:00'},
      {'name': '第5-6节', 'time': '14:00 - 15:35'},
      {'name': '第7-8节', 'time': '15:55 - 17:30'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppTheme.primaryDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '确认作息时间',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '我们为您预设了默认作息，可稍后在设置中修改',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),

          // 工作日作息
          Text(
            '工作日作息',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...weekdaySchedule.map((item) => _buildScheduleItem(
                item['name']!,
                item['time']!,
                theme,
                isDark,
              )),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '稍后可前往「设置」→「作息时间」自定义调整',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 第5页：完成页
  Widget _buildCompletePage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.accentGreen,
              size: 80,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            '准备就绪！',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '现在可以开始添加课程了',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 48),
          _buildSummaryItem(
            icon: Icons.person_outline_rounded,
            label: '姓名',
            value: _userName.isEmpty ? '未设置' : _userName,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            icon: Icons.school_outlined,
            label: '学期',
            value: '${_semesterStart.month}月${_semesterStart.day}日 · $_totalWeeks周',
            theme: theme,
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            icon: Icons.schedule_outlined,
            label: '作息',
            value: '已采用默认作息',
            theme: theme,
          ),
          const SizedBox(height: 48),
          Text(
            '点击「开始使用」进入应用\n然后到「课表」页面添加您的课程',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryDark, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem(String name, String time, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg2 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            time,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
