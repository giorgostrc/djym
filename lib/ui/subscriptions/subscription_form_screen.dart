import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/data/repositories/subscription_repository.dart';
import 'package:loggym/domain/money.dart';
import 'package:loggym/domain/subscription_period.dart';
import 'package:loggym/domain/unit_system.dart';

const _presetMonths = [1, 3, 12];

/// Adds, edits or renews a subscription. Renewing starts a new one from the
/// old one's title, cost and length.
class SubscriptionFormScreen extends ConsumerWidget {
  const SubscriptionFormScreen({
    this.subscriptionId,
    this.renewFromId,
    super.key,
  });

  final int? subscriptionId;
  final int? renewFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceId = subscriptionId ?? renewFromId;
    if (sourceId == null) return const _SubscriptionForm();

    final source = ref
        .watch(subscriptionsProvider)
        .value
        ?.where((overview) => overview.subscription.id == sourceId)
        .firstOrNull;
    if (source == null) return const Scaffold();

    return subscriptionId == null
        ? _SubscriptionForm(renewing: source)
        : _SubscriptionForm(existing: source);
  }
}

class _SubscriptionForm extends ConsumerStatefulWidget {
  const _SubscriptionForm({this.existing, this.renewing});

  final SubscriptionOverview? existing;
  final SubscriptionOverview? renewing;

  @override
  ConsumerState<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<_SubscriptionForm> {
  final _formKey = GlobalKey<FormState>();
  late final GymSubscription? _source =
      (widget.existing ?? widget.renewing)?.subscription;
  late final _title = TextEditingController(text: _source?.title);
  late final _cost = TextEditingController(
    text: _source == null
        ? null
        : formatNumber(_source.costCents / 100, decimals: 2),
  );
  late SubscriptionPeriod _period =
      widget.existing?.period ??
      widget.renewing?.period.renewedOn(DateTime.now()) ??
      SubscriptionPeriod.months(DateTime.now(), 1);
  var _dirty = false;

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  void _changePeriod(SubscriptionPeriod period) {
    _period = period;
    _markDirty();
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? firstDate}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: DateTime(2100),
      );

  Future<void> _pickStart() async {
    final start = await _pickDate(_period.start);
    if (start == null) return;
    final months = _period.wholeMonths;
    _changePeriod(
      months == null
          ? SubscriptionPeriod(
              start,
              _period.end.isBefore(start) ? start : _period.end,
            )
          : SubscriptionPeriod.months(start, months),
    );
  }

  Future<void> _pickEnd() async {
    final end = await _pickDate(_period.end, firstDate: _period.start);
    if (end != null) _changePeriod(SubscriptionPeriod(_period.start, end));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(subscriptionRepositoryProvider)
        .saveSubscription(
          id: widget.existing?.subscription.id,
          title: _title.text.trim(),
          costCents: parseMoney(_cost.text)!,
          period: _period,
        );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final subscription = widget.existing!.subscription;
    final repository = ref.read(subscriptionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    final linkedSessionIds = await repository.deleteSubscription(
      subscription.id,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('${subscription.title} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository
                .restoreSubscription(subscription, linkedSessionIds)
                .ignore(),
          ),
        ),
      );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).value?.currencyCode ?? 'EUR';
    final dates = DateFormat.yMMMEd();
    final days = _period.lengthInDays;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch ((widget.existing, widget.renewing)) {
            (null, null) => 'New subscription',
            (_?, _) => 'Edit subscription',
            (_, _?) => 'Renew subscription',
          }),
          actions: [
            TextButton(onPressed: _save, child: const Text('Save')),
            if (widget.existing != null)
              PopupMenuButton<void>(
                tooltip: 'Subscription options',
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: _delete,
                    child: const Text('Delete subscription'),
                  ),
                ],
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  spacing: 16,
                  children: [
                    TextFormField(
                      controller: _title,
                      autofocus: _source == null,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Gym',
                        hintText: 'e.g. City Gym',
                        counterText: '',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Name the gym or subscription'
                          : null,
                      onChanged: (_) => _markDirty(),
                    ),
                    TextFormField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Cost',
                        suffixText: currency,
                      ),
                      validator: (value) => parseMoney(value ?? '') == null
                          ? 'Enter what you paid'
                          : null,
                      onChanged: (_) => _markDirty(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final months in _presetMonths)
                      ChoiceChip(
                        label: Text(months == 1 ? '1 month' : '$months months'),
                        selected: _period.wholeMonths == months,
                        onSelected: (_) => _changePeriod(
                          SubscriptionPeriod.months(_period.start, months),
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Starts'),
                subtitle: Text(dates.format(_period.start)),
                onTap: _pickStart,
              ),
              ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('Ends'),
                subtitle: Text(
                  '${dates.format(_period.end)} · '
                  '${days == 1 ? '1 day' : '$days days'}',
                ),
                onTap: _pickEnd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
