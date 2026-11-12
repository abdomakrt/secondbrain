import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/core/hlc.dart';

void main() {
  group('format & parse', () {
    test('13-digit ms + 4-hex counter + device id', () {
      final c = HlcClock(deviceId: 'd1', nowMs: () => 1700000000000);
      final h = c.tick();
      expect(h.length, greaterThanOrEqualTo(18));
      expect(h, matches(RegExp(r'^\d{13}-[0-9a-f]{4}-d1$')));
      final p = HlcClock.parse(h);
      expect(p.ms, 1700000000000);
      expect(p.counter, 0);
      expect(p.deviceId, 'd1');
    });

    test('device id containing dashes survives parse', () {
      final c = HlcClock(deviceId: 'a-b-c-uuid', nowMs: () => 5);
      final h = c.tick();
      expect(HlcClock.parse(h).deviceId, 'a-b-c-uuid');
    });

    test('lexical order equals logical order', () {
      final c = HlcClock(deviceId: 'd1', nowMs: () => 10);
      final h1 = c.tick();
      final h2 = c.tick();
      expect(h2.compareTo(h1), greaterThan(0));
    });
  });

  group('tick', () {
    test('same ms increments the counter', () {
      final c = HlcClock(deviceId: 'd1', nowMs: () => 10);
      final h1 = c.tick();
      final h2 = c.tick();
      expect(HlcClock.parse(h2).counter, HlcClock.parse(h1).counter + 1);
    });

    test('monotonic even if wall clock goes backwards', () {
      var now = 100;
      final c = HlcClock(deviceId: 'd1', nowMs: () => now);
      final h1 = c.tick();
      now = 50; // clock skew backwards
      final h2 = c.tick();
      expect(HlcClock.parse(h2).ms, 100);
      expect(h2.compareTo(h1), greaterThan(0));
    });

    test('counter overflow bumps ms and keeps width', () {
      var now = 100;
      final c = HlcClock(deviceId: 'd1', nowMs: () => now);
      final h1 = c.tick();
      // 0xffff + 1 more ticks on the same ms must overflow exactly once.
      now = 99; // freeze logical clock
      String h = h1;
      for (var i = 0; i <= 0xffff; i++) {
        h = c.tick();
      }
      final p = HlcClock.parse(h);
      expect(p.ms, 101);
      expect(p.counter, 0);
      expect(h, matches(RegExp(r'^\d{13}-[0-9a-f]{4}-d1$')));
    });
  });

  group('recv', () {
    test('adopts a newer remote clock', () {
      var now = 100;
      final c = HlcClock(deviceId: 'd1', nowMs: () => now);
      final remote = HlcClock(deviceId: 'd2', nowMs: () => 500).tick();
      c.recv(remote);
      expect(c.lastMs, 500);
    });

    test('keeps local when remote is older', () {
      var now = 500;
      final c = HlcClock(deviceId: 'd1', nowMs: () => now);
      final local = c.tick();
      final remote = HlcClock(deviceId: 'd2', nowMs: () => 10).tick();
      c.recv(remote);
      expect(HlcClock.parse(c.last).ms, HlcClock.parse(local).ms);
      // recv is still an event: counter moved.
      expect(HlcClock.parse(c.last).counter,
          HlcClock.parse(local).counter + 1);
    });

    test('equal ms takes max counter + 1', () {
      var now = 100;
      final c = HlcClock(deviceId: 'd1', nowMs: () => now);
      final local = c.tick(); // counter 0
      final r = HlcClock(deviceId: 'd2', nowMs: () => 100);
      r.tick();
      final remote = r.tick(); // counter 1
      c.recv(remote);
      expect(HlcClock.parse(c.last).counter, 2);
      expect(HlcClock.parse(c.last).ms, HlcClock.parse(local).ms);
    });

    test('after recv the clock stays ordered (larger wins on conflict)', () {
      final remote = HlcClock(deviceId: 'd2', nowMs: () => 999).tick();
      final c = HlcClock(deviceId: 'd1', nowMs: () => 10);
      c.recv(remote);
      final next = c.tick();
      expect(next.compareTo(remote), greaterThan(0));
    });
  });
}
