import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../combo/models/combo_model.dart';
import '../../combo/providers/combo_provider.dart';
import '../../combo/repositories/combo_repository.dart';
import '../../scenarios/data/scenario_repository.dart';
import '../../scenarios/models/scenario.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../widgets/export_panel.dart';
import '../widgets/import_panel.dart';

class MarketPackageItem {
  const MarketPackageItem({
    required this.id,
    required this.code,
    this.sellerId,
    required this.sellerName,
    required this.isOfficial,
    required this.title,
    required this.description,
    required this.categoryTag,
    required this.priceVnd,
    required this.comboCount,
    required this.scenarioCount,
    required this.downloadCount,
    required this.ratingAvg,
    required this.isPurchased,
    required this.isOwner,
    required this.combos,
    required this.customScenarios,
  });

  final String id;
  final String code;
  final String? sellerId;
  final String sellerName;
  final bool isOfficial;
  final String title;
  final String description;
  final String categoryTag;
  final int priceVnd;
  final int comboCount;
  final int scenarioCount;
  final int downloadCount;
  final double ratingAvg;
  final bool isPurchased;
  final bool isOwner;
  final List<Map<String, dynamic>> combos;
  final List<Map<String, dynamic>> customScenarios;

  factory MarketPackageItem.fromJson(Map<String, dynamic> json) =>
      MarketPackageItem(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        sellerId: json['sellerId'] as String?,
        sellerName: (json['sellerName'] as String?) ?? 'Cộng đồng',
        isOfficial: (json['isOfficial'] as bool?) ?? false,
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        categoryTag: (json['categoryTag'] as String?) ?? 'Tình huống',
        priceVnd: (json['priceVnd'] as num?)?.toInt() ?? 0,
        comboCount: (json['comboCount'] as num?)?.toInt() ?? 0,
        scenarioCount: (json['scenarioCount'] as num?)?.toInt() ?? 0,
        downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
        ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 5.0,
        isPurchased: (json['isPurchased'] as bool?) ?? false,
        isOwner: (json['isOwner'] as bool?) ?? false,
        combos: ((json['combos'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        customScenarios: ((json['customScenarios'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

String _formatVnd(int amount) {
  if (amount <= 0) return 'Miễn phí';
  final str = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${buffer.toString()}đ';
}

enum SharingScreenTab { export, import, market }

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});
  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  SharingScreenTab _activeTab = SharingScreenTab.export;
  bool _initializedTab = false;
  String _tab = 'official'; // 'official' | 'community' | 'mine'
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<MarketPackageItem> _packages = const [];
  String? _buyingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedTab) {
      _initializedTab = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == SharingScreenTab.market || args == 'market') {
        _activeTab = SharingScreenTab.market;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final q = Uri.encodeQueryComponent(_searchController.text.trim());
      final rawList = await api.getList(
        '/market/packages?filter=$_tab&search=$q',
      );
      if (!mounted) return;
      setState(() {
        _packages = rawList.map(MarketPackageItem.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Không thể kết nối tới Chợ tình huống.';
        _loading = false;
      });
    }
  }

  Future<void> _buyOrClaim(MarketPackageItem pkg) async {
    if (!pkg.isPurchased && pkg.priceVnd > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mua gói tình huống'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pkg.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Đăng bởi: ${pkg.sellerName}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Text(
                'Bao gồm ${pkg.comboCount} combo${pkg.scenarioCount > 0 ? ' và ${pkg.scenarioCount} kịch bản hội thoại mới' : ''}. Sau khi thanh toán, toàn bộ gói sẽ được lưu thẳng vào tài khoản của bạn.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng thanh toán:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _formatVnd(pkg.priceVnd),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Thanh toán ${_formatVnd(pkg.priceVnd)}'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _buyingId = pkg.id);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.postJson('/market/packages/${pkg.id}/buy', {});
      final addedCombos = (res['addedCombosCount'] as num?)?.toInt() ?? 0;

      if (mounted) {
        showMessage(
          context,
          'Đã nhận gói “${pkg.title}” (+$addedCombos combo đã lưu vào CSDL).',
        );
      }

      // Safely refresh local providers and package listing from DB without masking purchase success
      try {
        ref.invalidate(comboListProvider);
        ref.invalidate(scenarioLibraryProvider);
        await ref.read(comboListProvider.future);
        await ref.read(scenarioLibraryProvider.future);
        await ref.read(authStateProvider.notifier).refreshProfile();
      } catch (_) {}
      try {
        await _loadPackages();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Không thể mua gói lúc này.',
        );
      }
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  Future<void> _deleteListing(MarketPackageItem pkg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gỡ gói khỏi Chợ?'),
        content: Text('Gói “${pkg.title}” sẽ bị gỡ khỏi Chợ tình huống.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ gói', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiClientProvider).delete('/market/packages/${pkg.id}');
      await _loadPackages();
      if (mounted) {
        showMessage(context, 'Đã gỡ gói khỏi Chợ.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Không thể gỡ gói lúc này.',
        );
      }
    }
  }

  Future<void> _openPackageDetail(MarketPackageItem pkg) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _SourceBadge(isOfficial: pkg.isOfficial),
                    const SizedBox(width: 8),
                    Text(
                      pkg.categoryTag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatVnd(pkg.priceVnd),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(pkg.title, style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text(
                  'Đăng bởi ${pkg.sellerName} · Mã: ${pkg.code} · ${pkg.downloadCount} lượt nhận · ★ ${pkg.ratingAvg.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Text(pkg.description, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                Text(
                  'COMBO TRONG GÓI (${pkg.combos.length})',
                  style: AppTextStyles.section.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                for (final c in pkg.combos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_callback_rounded,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (c['name'] as String?) ?? 'Combo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Giao diện: ${(c['callInterface'] as String? ?? 'phone').toUpperCase()} · ${c['callType'] == 'video' ? 'Gọi video: ${c['callerName'] ?? ''}' : 'Kịch bản: ${c['scenarioId']}'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (pkg.customScenarios.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'KỊCH BẢN HỘI THOẠI KÈM THEO (${pkg.customScenarios.length})',
                    style: AppTextStyles.section.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final sc in pkg.customScenarios)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${sc['title']} (Người gọi: ${sc['callerName']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final st
                                in ((sc['steps'] as List?) ?? const []))
                              if ((st as Map)['type'] == 'speech')
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• “${st['text']}”',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                AppButton(
                  label: pkg.isPurchased
                      ? 'Đã sở hữu · Tải lại combo vào máy'
                      : pkg.priceVnd <= 0
                      ? 'Nhận gói miễn phí ngay'
                      : 'Mua gói · ${_formatVnd(pkg.priceVnd)}',
                  icon: pkg.isPurchased
                      ? Icons.download_done_rounded
                      : Icons.shopping_bag_outlined,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _buyOrClaim(pkg);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPublishSheet(List<ComboModel> userCombos) async {
    if (userCombos.isEmpty) {
      showMessage(context, 'Bạn cần có ít nhất 1 combo để đăng lên Chợ.');
      return;
    }
    final published = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PublishPackageSheet(userCombos: userCombos),
    );
    if (published == true && mounted) {
      setState(() => _tab = 'mine');
      await _loadPackages();
      if (mounted) {
        showMessage(context, 'Đã đăng gói tình huống lên Chợ thành công!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final combosAsync = ref.watch(comboListProvider);
    final userCombos = combosAsync.value ?? const <ComboModel>[];

    return ScreenShell(
      title: _activeTab == SharingScreenTab.market
          ? 'Chợ tình huống'
          : 'Chia sẻ combo',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<SharingScreenTab>(
                segments: const [
                  ButtonSegment(
                    value: SharingScreenTab.export,
                    label: Text('Xuất'),
                  ),
                  ButtonSegment(
                    value: SharingScreenTab.import,
                    label: Text('Nhập'),
                  ),
                  ButtonSegment(
                    value: SharingScreenTab.market,
                    label: Text('Chợ'),
                  ),
                ],
                selected: {_activeTab},
                onSelectionChanged: (selected) =>
                    setState(() => _activeTab = selected.first),
              ),
            ),
          ),
          Expanded(
            child: switch (_activeTab) {
              SharingScreenTab.export => SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                child: ExportPanel(
                  combos: userCombos,
                  onImport: () =>
                      setState(() => _activeTab = SharingScreenTab.import),
                ),
              ),
              SharingScreenTab.import => SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                child: ImportPanel(existingCombos: userCombos),
              ),
              SharingScreenTab.market => _buildMarketView(context, userCombos),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarketView(
    BuildContext context,
    List<ComboModel> userCombos,
  ) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
        child: Column(
          children: [
            // 3 Filter Tabs: Nhà sản xuất | Cộng đồng | Đăng / Của tôi
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  for (final entry in const [
                    ('official', 'Nhà sản xuất'),
                    ('community', 'Cộng đồng'),
                    ('mine', 'Của tôi'),
                  ])
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() => _tab = entry.$1);
                          _loadPackages();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: _tab == entry.$1 ? 1 : 0.55),
                          backgroundColor: _tab == entry.$1
                              ? Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.09)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          entry.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Search & Publish Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadPackages(),
                    decoration: InputDecoration(
                      hintText: 'Tìm gói công việc, gia đình, tiệc tùng...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _loadPackages();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _openPublishSheet(userCombos),
                  icon: const Icon(Icons.upload_rounded, size: 17),
                  label: const Text('Đăng gói'),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const AppLoading()
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadPackages,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : _packages.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 42,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tab == 'mine'
                            ? 'Bạn chưa mua hoặc đăng gói tình huống nào.'
                            : 'Chưa có gói tình huống nào khớp tìm kiếm.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (_tab == 'mine')
                        AppButton(
                          label: 'Đăng gói tình huống của bạn lên Chợ',
                          onPressed: () => _openPublishSheet(userCombos),
                        ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadPackages,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  itemCount: _packages.length,
                  itemBuilder: (context, index) {
                    final pkg = _packages[index];
                    final isBuying = _buyingId == pkg.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        onTap: () => _openPackageDetail(pkg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _SourceBadge(isOfficial: pkg.isOfficial),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pkg.categoryTag,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pkg.priceVnd <= 0
                                        ? Colors.green.withValues(alpha: 0.16)
                                        : AppColors.accent.withValues(
                                            alpha: 0.18,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _formatVnd(pkg.priceVnd),
                                    style: TextStyle(
                                      color: pkg.priceVnd <= 0
                                          ? Colors.greenAccent
                                          : AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(pkg.title, style: AppTextStyles.cardTitle),
                            const SizedBox(height: 4),
                            Text(
                              pkg.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${pkg.sellerName} · ${pkg.comboCount} combo · ${pkg.downloadCount} lượt tải · ★ ${pkg.ratingAvg.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => _openPackageDetail(pkg),
                                  child: const Text('Xem chi tiết'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: isBuying
                                        ? null
                                        : () => _buyOrClaim(pkg),
                                    icon: Icon(
                                      pkg.isPurchased
                                          ? Icons.check_circle_outline
                                          : Icons.shopping_cart_checkout,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isBuying
                                          ? 'Đang xử lý...'
                                          : pkg.isPurchased
                                          ? 'Đã sở hữu · Tải về'
                                          : pkg.priceVnd <= 0
                                          ? 'Nhận miễn phí'
                                          : 'Mua ${_formatVnd(pkg.priceVnd)}',
                                    ),
                                  ),
                                ),
                                if (pkg.isOwner) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    tooltip: 'Gỡ gói khỏi Chợ',
                                    onPressed: () => _deleteListing(pkg),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.red,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isOfficial});
  final bool isOfficial;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isOfficial
          ? AppColors.accent.withValues(alpha: 0.2)
          : Colors.blueAccent.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOfficial ? Icons.verified_rounded : Icons.people_alt_outlined,
          size: 13,
          color: isOfficial ? AppColors.accent : Colors.lightBlueAccent,
        ),
        const SizedBox(width: 4),
        Text(
          isOfficial ? 'NHÀ SẢN XUẤT' : 'CỘNG ĐỒNG',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isOfficial ? AppColors.accent : Colors.lightBlueAccent,
          ),
        ),
      ],
    ),
  );
}

class _PublishPackageSheet extends ConsumerStatefulWidget {
  const _PublishPackageSheet({required this.userCombos});
  final List<ComboModel> userCombos;

  @override
  ConsumerState<_PublishPackageSheet> createState() =>
      _PublishPackageSheetState();
}

class _PublishPackageSheetState extends ConsumerState<_PublishPackageSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Công việc';
  int _priceVnd = 0;
  late final Set<String> _selectedIds = {widget.userCombos.first.id};
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'Vui lòng nhập tên gói tình huống.');
      return;
    }
    if (_selectedIds.isEmpty) {
      showMessage(context, 'Chọn ít nhất 1 combo để đăng lên Chợ.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      ScenarioRepository? scenarioRepo;
      try {
        scenarioRepo = await ref.read(scenarioLibraryProvider.future);
      } catch (_) {
        scenarioRepo = ref.read(scenarioRepositoryProvider);
      }
      final selectedCombos = widget.userCombos
          .where((c) => _selectedIds.contains(c.id))
          .toList();

      final customScenarios = <Map<String, dynamic>>[];
      final seenScenarioIds = <String>{};
      if (scenarioRepo != null) {
        for (final c in selectedCombos) {
          // Gọi video không dùng kịch bản: không gửi kèm kịch bản cá nhân.
          final sc = c.isVideoCall
              ? null
              : scenarioRepo.findScenario(c.scenarioId);
          if (sc != null &&
              sc.source == ScenarioSource.user &&
              seenScenarioIds.add(sc.id)) {
            customScenarios.add({
              'id': sc.id,
              'title': sc.title,
              'category': sc.category.name,
              'source': 'user',
              'callerName': sc.callerName,
              'initial': sc.initial,
              'estimatedSeconds': sc.estimatedSeconds,
              'defaultBackgroundId': sc.defaultBackgroundId,
              'isPro': false,
              'steps': sc.steps
                  .map(
                    (st) => {
                      'id': st.id,
                      'type': st.type.name,
                      'text': st.text,
                      'audioPath': st.audioPath,
                      'mediaFileId': null,
                      'seconds': st.seconds,
                    },
                  )
                  .toList(),
            });
          }
        }
      }

      final descText = _descCtrl.text.trim();
      await api.postJson('/market/packages', {
        'title': title,
        'description': descText.isEmpty ? null : descText,
        'categoryTag': _category,
        'priceVnd': _priceVnd,
        'combos': selectedCombos.map(ComboRepository.toServerMap).toList(),
        'customScenarios': customScenarios,
        'customAmbientSounds': const <Map<String, dynamic>>[],
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Không thể đăng gói lúc này.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Đăng gói tình huống lên Chợ',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 6),
            const Text(
              'Chia sẻ miễn phí hoặc đặt giá bán cho bộ combo và kịch bản của bạn.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên gói tình huống *',
                hintText: 'VD: Combo thoát họp khẩn cấp...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mô tả gói',
                hintText: 'Giới thiệu ngắn về các tình huống có trong gói...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Chủ đề',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Công việc',
                        child: Text('Công việc'),
                      ),
                      DropdownMenuItem(
                        value: 'Gia đình',
                        child: Text('Gia đình'),
                      ),
                      DropdownMenuItem(
                        value: 'Tiệc tùng',
                        child: Text('Tiệc tùng'),
                      ),
                      DropdownMenuItem(value: 'Hẹn hò', child: Text('Hẹn hò')),
                      DropdownMenuItem(
                        value: 'Cộng đồng',
                        child: Text('Cộng đồng'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _priceVnd,
                    decoration: const InputDecoration(
                      labelText: 'Giá bán',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Miễn phí (0đ)')),
                      DropdownMenuItem(value: 15000, child: Text('15.000đ')),
                      DropdownMenuItem(value: 29000, child: Text('29.000đ')),
                      DropdownMenuItem(value: 49000, child: Text('49.000đ')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _priceVnd = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'CHỌN COMBO ĐƯA VÀO GÓI (${_selectedIds.length})',
              style: AppTextStyles.section.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            for (final combo in widget.userCombos)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selectedIds.contains(combo.id),
                title: Text(combo.name),
                subtitle: Text(
                  combo.isVideoCall
                      ? 'Gọi video: ${combo.callerName ?? ''}'
                      : 'Kịch bản: ${combo.scenarioId}',
                ),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedIds.add(combo.id);
                    } else {
                      _selectedIds.remove(combo.id);
                    }
                  });
                },
              ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Đăng gói lên Chợ ngay',
              icon: Icons.publish_rounded,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
