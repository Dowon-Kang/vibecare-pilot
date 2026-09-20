import { describe, expect, it } from 'vitest';
import {
  PostgresDatabase,
  toPostgresSql,
  type QueryResultLike,
} from '../src/storage/postgres-database';

type QueryCall = { text: string; values?: readonly unknown[] };

class FakeClient {
  readonly calls: QueryCall[] = [];
  released = false;

  constructor(private readonly failOn?: string) {}

  async query(text: string, values?: readonly unknown[]): Promise<QueryResultLike> {
    this.calls.push({ text, values });
    if (this.failOn && text.includes(this.failOn)) throw new Error('database failure');
    if (text.startsWith('SELECT')) return { rows: [{ value: 7 }], rowCount: 1 };
    return { rows: [], rowCount: 1 };
  }

  release(): void {
    this.released = true;
  }
}

class FakePool {
  readonly calls: QueryCall[] = [];

  constructor(readonly client = new FakeClient()) {}

  async query(text: string, values?: readonly unknown[]): Promise<QueryResultLike> {
    this.calls.push({ text, values });
    if (text.startsWith('SELECT')) return { rows: [{ value: 7 }], rowCount: 1 };
    return { rows: [], rowCount: 1 };
  }

  async connect(): Promise<FakeClient> {
    return this.client;
  }

  async end(): Promise<void> {}
}

describe('PostgresDatabase', () => {
  it('translates D1 placeholders without replacing quoted question marks', () => {
    expect(toPostgresSql("SELECT '?' AS literal, value FROM sample WHERE a = ? AND b = '?' AND c = ?"))
      .toBe("SELECT '?' AS literal, value FROM sample WHERE a = $1 AND b = '?' AND c = $2");
  });

  it('supports prepare, bind, first, all and run through the SQL port', async () => {
    const pool = new FakePool();
    const database = new PostgresDatabase(pool);

    await expect(database.prepare('SELECT value FROM sample WHERE id = ?').bind('A').first<number>('value'))
      .resolves.toBe(7);
    await expect(database.prepare('SELECT value FROM sample WHERE id = ?').bind('A').all<{ value: number }>())
      .resolves.toEqual({ results: [{ value: 7 }] });
    await expect(database.prepare('UPDATE sample SET value = ? WHERE id = ?').bind(8, 'A').run())
      .resolves.toEqual({ success: true, meta: { changes: 1 } });

    expect(pool.calls).toContainEqual({
      text: 'SELECT value FROM sample WHERE id = $1',
      values: ['A'],
    });
  });

  it('executes batches atomically on one client', async () => {
    const client = new FakeClient();
    const database = new PostgresDatabase(new FakePool(client));

    await database.batch([
      database.prepare('INSERT INTO sample(id) VALUES (?)').bind('A'),
      database.prepare('UPDATE sample SET value = ? WHERE id = ?').bind(8, 'A'),
    ]);

    expect(client.calls.map((call) => call.text)).toEqual([
      'BEGIN',
      'INSERT INTO sample(id) VALUES ($1)',
      'UPDATE sample SET value = $1 WHERE id = $2',
      'COMMIT',
    ]);
    expect(client.released).toBe(true);
  });

  it('rolls back and releases the client when a batch fails', async () => {
    const client = new FakeClient('BROKEN');
    const database = new PostgresDatabase(new FakePool(client));

    await expect(database.batch([
      database.prepare('INSERT INTO sample(id) VALUES (?)').bind('A'),
      database.prepare('BROKEN ?').bind('B'),
    ])).rejects.toThrow('database failure');

    expect(client.calls.at(-1)?.text).toBe('ROLLBACK');
    expect(client.released).toBe(true);
  });
});
