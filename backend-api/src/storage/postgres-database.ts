import { Pool } from 'pg';
import type { PoolConfig } from 'pg';
import type { SqlDatabase, SqlStatement } from '../app-context.js';

export type QueryResultLike = {
  rows: Record<string, unknown>[];
  rowCount: number | null;
};

export type Queryable = {
  query(text: string, values?: readonly unknown[]): Promise<QueryResultLike>;
};

export type TransactionClient = Queryable & { release(): void };
export type PoolLike = Queryable & {
  connect(): Promise<TransactionClient>;
  end(): Promise<void>;
};

/** Convert the D1-style placeholders used behind the application SQL port. */
export function toPostgresSql(sql: string): string {
  let result = '';
  let parameter = 0;
  let quote: "'" | '"' | null = null;
  for (let index = 0; index < sql.length; index += 1) {
    const character = sql[index];
    if (quote) {
      result += character;
      if (character === quote) {
        if (sql[index + 1] === quote) {
          result += sql[index + 1];
          index += 1;
        } else quote = null;
      }
      continue;
    }
    if (character === "'" || character === '"') {
      quote = character;
      result += character;
    } else if (character === '?') {
      result += `$${++parameter}`;
    } else result += character;
  }
  return result;
}

class PostgresStatement implements SqlStatement {
  private readonly values: unknown[];

  constructor(
    readonly database: PostgresDatabase,
    readonly sql: string,
    values: readonly unknown[] = [],
  ) {
    this.values = [...values];
  }

  bind(...values: unknown[]): PostgresStatement {
    return new PostgresStatement(this.database, this.sql, values);
  }

  async first<T = Record<string, unknown>>(column?: string): Promise<T | null> {
    const row = (await this.database.query(this.sql, this.values)).rows[0];
    if (!row) return null;
    return column ? ((row[column] as T | undefined) ?? null) : row as T;
  }

  async all<T = Record<string, unknown>>(): Promise<{ results: T[] }> {
    return { results: (await this.database.query(this.sql, this.values)).rows as T[] };
  }

  async run(): Promise<unknown> {
    return this.runWith(this.database);
  }

  async runWith(queryable: Queryable): Promise<unknown> {
    const result = await queryable.query(toPostgresSql(this.sql), this.values);
    return { success: true, meta: { changes: result.rowCount ?? 0 } };
  }
}

export class PostgresDatabase implements SqlDatabase, Queryable {
  constructor(private readonly pool: PoolLike) {}

  static fromConfig(config: PoolConfig): PostgresDatabase {
    return new PostgresDatabase(new Pool(config) as unknown as PoolLike);
  }

  prepare(sql: string): SqlStatement {
    return new PostgresStatement(this, sql);
  }

  async query(sql: string, values: readonly unknown[] = []): Promise<QueryResultLike> {
    return this.pool.query(toPostgresSql(sql), values);
  }

  async batch(statements: SqlStatement[]): Promise<unknown[]> {
    const prepared = statements.map((statement) => {
      if (!(statement instanceof PostgresStatement) || statement.database !== this) {
        throw new Error('POSTGRES_BATCH_STATEMENT_MISMATCH');
      }
      return statement;
    });
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const results: unknown[] = [];
      for (const statement of prepared) results.push(await statement.runWith(client));
      await client.query('COMMIT');
      return results;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
