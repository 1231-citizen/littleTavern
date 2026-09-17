import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';

/// ============================================================
///  API 接入 —— 模型、推理等级与采样参数
/// ============================================================
class ApiScreen extends StatefulWidget {
  final AppStore store;
  const ApiScreen({super.key, required this.store});

  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> {
  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _tokens;
  late final TextEditingController _extra;

  late ReasoningLevel _reasoning;
  late bool _sendEffort;
  late bool _stream;
  late double _temp;
  bool _obscure = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final a = widget.store.api;
    _base = TextEditingController(text: a.baseUrl);
    _key = TextEditingController(text: a.apiKey);
    _model = TextEditingController(text: a.model);
    _tokens = TextEditingController(text: '${a.maxTokens}');
    _extra = TextEditingController(text: a.extraJson);
    _reasoning = a.reasoning;
    _sendEffort = a.sendReasoningEffort;
    _stream = a.stream;
    _temp = a.temperature;
  }

  @override
  void dispose() {
    _base.dispose();
    _key.dispose();
    _model.dispose();
    _tokens.dispose();
    _extra.dispose();
    super.dispose();
  }

  ApiConfig _collect() {
    final cfg = widget.store.api.clone();
    cfg.baseUrl = _base.text.trim();
    cfg.apiKey = _key.text.trim();
    cfg.model = _model.text.trim();
    cfg.reasoning = _reasoning;
    cfg.sendReasoningEffort = _sendEffort;
    cfg.stream = _stream;
    cfg.temperature = _temp;
    cfg.maxTokens = int.tryParse(_tokens.text.trim()) ?? 2048;
    cfg.extraJson = _extra.text;
    return cfg;
  }

  Future<void> _save() async {
    final cfg = _collect();
    if (cfg.extraJsonError != null) {
      jfToast(context, '附加参数 JSON 有误，请先修正');
      return;
    }
    await widget.store.updateApi(cfg);
    if (mounted) {
      jfToast(context, 'API 配置已保存');
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _test() async {
    final cfg = _collect();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final r = await widget.store.testApi(cfg);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final extraErr = _collect().extraJsonError;

    return JFPage(
      title: 'API 接入',
      subtitle: 'DeepSeek / OpenAI 兼容接口',
      trailing: JFButton(label: '保存', primary: true, dense: true, onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Botanical(size: 54, variant: 2, color: JF.pink),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  '请求由本机直接发出，不经过任何中转服务器。\nAPI Key 只写入本机存储，请勿分享截图。',
                  style: JF.small.copyWith(height: 1.9),
                ),
              ),
            ],
          ),
          const JFMa(40),

          const JFSectionLabel('接口', trailing: '必填'),
          JFField(
            label: '接口地址',
            hint: 'https://api.deepseek.com',
            controller: _base,
            keyboardType: TextInputType.url,
          ),
          const JFMa(26),
          JFField(
            label: 'API Key',
            hint: 'sk-…',
            controller: _key,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 17,
                color: JF.muted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),

          const JFMa(44),
          const JFSectionLabel('模型'),
          JFChips<String>(
            values: const ['deepseek-chat', 'deepseek-reasoner'],
            selected: _model.text.trim(),
            label: (v) => v,
            onChanged: (v) => setState(() => _model.text = v),
          ),
          const JFMa(22),
          JFField(
            label: '模型名称',
            hint: 'deepseek-chat',
            controller: _model,
            onChanged: (_) => setState(() {}),
          ),

          const JFMa(44),
          const JFSectionLabel('推理等级', trailing: '思维链由模型返回'),
          JFChips<ReasoningLevel>(
            values: ReasoningLevel.values,
            selected: _reasoning,
            label: reasoningLabel,
            onChanged: (v) => setState(() => _reasoning = v),
          ),
          const JFMa(20),
          Text(
            _reasoning == ReasoningLevel.off
                ? '关闭思考：直接给出回复，速度更快。'
                : '已开启推理。DeepSeek 的深度思考需使用 deepseek-reasoner 模型，'
                    '返回的思维链可在对话中长按气泡查看。',
            style: JF.tiny.copyWith(height: 1.9),
          ),
          const JFMa(18),
          JFSwitchRow(
            title: '发送 reasoning_effort 参数',
            subtitle: '仅部分兼容接口支持；若报 400 请关闭此项',
            value: _sendEffort,
            onChanged: (v) => setState(() => _sendEffort = v),
          ),

          const JFMa(40),
          const JFSectionLabel('采样'),
          JFSliderRow(
            title: '温度',
            valueText: _temp.toStringAsFixed(2),
            value: _temp,
            onChanged: (v) => setState(() => _temp = v),
          ),
          const JFMa(14),
          JFField(
            label: '最大输出长度 (tokens)',
            controller: _tokens,
            keyboardType: TextInputType.number,
          ),
          const JFMa(10),
          JFSwitchRow(
            title: '流式输出',
            subtitle: '逐字显示回复，可随时停止',
            value: _stream,
            onChanged: (v) => setState(() => _stream = v),
          ),

          const JFMa(40),
          const JFSectionLabel('高级'),
          JFField(
            label: '附加请求参数 (JSON)',
            hint: '{"thinking": {"type": "enabled"}}',
            controller: _extra,
            maxLines: 4,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            errorText: extraErr,
            onChanged: (_) => setState(() {}),
          ),

          const JFMa(46),
          Row(
            children: [
              Expanded(
                child: JFButton(
                  label: _testing ? '正在测试…' : '测试连接',
                  expand: true,
                  icon: Icons.wifi_tethering,
                  onPressed: _testing ? null : _test,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: JFButton(
                  label: '保存配置',
                  primary: true,
                  expand: true,
                  onPressed: _save,
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const JFMa(24),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
              decoration: JF.panel(color: JF.paper),
              child: Text(_testResult!, style: JF.small.copyWith(height: 1.8)),
            ),
          ],
          const JFMa(20),
          Text(
            '提示：DeepSeek 官方地址为 https://api.deepseek.com，'
            '也接受带 /v1 的写法。若使用第三方中转，请填写其完整兼容地址。',
            style: JF.tiny.copyWith(height: 1.9),
          ),
        ],
      ),
    );
  }
}
