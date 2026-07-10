import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase schema cascades soft deletes across owned child rows', () {
    final schema = File('supabase/schema.sql').readAsStringSync();
    final activityCascade =
        _functionBody(schema, 'public.soft_delete_activity_children');
    final categoryCascade =
        _functionBody(schema, 'public.soft_delete_activity_category_children');

    expect(schema, contains('create extension if not exists pgcrypto;'));
    expect(schema, isNot(contains('security definer')));
    expect(
      schema,
      contains('create trigger activities_soft_delete_children'),
    );
    expect(
      schema,
      contains('create trigger activity_categories_soft_delete_children'),
    );

    expect(activityCascade, contains('update public.time_entries'));
    expect(activityCascade, contains('update public.activity_category_links'));
    expect(activityCascade, contains('activity_id = new.id'));
    expect(activityCascade, contains('user_id = new.user_id'));
    expect(activityCascade, contains('is_deleted = false'));
    expect(activityCascade, contains('greatest('));

    expect(categoryCascade, contains('update public.activity_category_links'));
    expect(categoryCascade, contains('category_id = new.id'));
    expect(categoryCascade, contains('user_id = new.user_id'));
    expect(categoryCascade, contains('is_deleted = false'));
    expect(categoryCascade, contains('greatest('));
  });

  test('Supabase RLS policies use authenticated owned-row predicates', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    for (final table in const [
      'activities',
      'activity_categories',
      'activity_category_links',
      'time_entries',
      'action_logs',
      'profiles',
    ]) {
      final tablePolicies = _policyBlock(schema, table);
      expect(tablePolicies, contains('to authenticated'));
      expect(tablePolicies, contains('((select auth.uid()) = user_id)'));
      expect(tablePolicies, isNot(contains('auth.uid() = user_id')));
    }

    expect(
      schema,
      contains(
        'exists (select 1 from public.activities where id = activity_id',
      ),
    );
    expect(
      schema,
      contains(
        'exists (select 1 from public.activity_categories where id = category_id',
      ),
    );
    expect(
      schema,
      contains(
        'exists (select 1 from public.time_entries where id = entry_id',
      ),
    );
  });

  test('Supabase schema grants only the authenticated data API surface', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    expect(
      schema,
      contains('grant usage on schema public to authenticated;'),
    );
    expect(
      schema,
      contains('grant select, insert, update on'),
    );
    expect(schema, contains('public.activities'));
    expect(schema, contains('public.activity_categories'));
    expect(schema, contains('public.activity_category_links'));
    expect(schema, contains('public.time_entries'));
    expect(schema, contains('public.action_logs'));
    expect(schema, contains('public.profiles'));
    expect(schema, isNot(contains(' to anon;')));
    expect(schema, isNot(contains('grant delete')));
  });
}

String _functionBody(String schema, String functionName) {
  final signature = 'create or replace function $functionName()';
  final start = schema.indexOf(signature);
  expect(start, isNonNegative);
  final bodyStart = schema.indexOf(r'$$', start);
  expect(bodyStart, isNonNegative);
  final bodyEnd = schema.indexOf(r'$$;', bodyStart + 2);
  expect(bodyEnd, isNonNegative);
  return schema.substring(bodyStart, bodyEnd);
}

String _policyBlock(String schema, String table) {
  final blocks = <String>[];
  var searchFrom = 0;
  while (true) {
    final start = schema.indexOf('on public.$table for', searchFrom);
    if (start == -1) {
      break;
    }
    final end = schema.indexOf(';', start);
    expect(end, isNonNegative, reason: 'unterminated policy for $table');
    blocks.add(schema.substring(start, end));
    searchFrom = end + 1;
  }
  expect(blocks, isNotEmpty, reason: 'missing policies for $table');
  return blocks.join('\n');
}
