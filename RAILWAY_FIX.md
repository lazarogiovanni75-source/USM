# Fix: No unique index found for id on ai_messages

## Problem
Rails `insert_all` requires an explicit unique index on the `id` column, but Railway's production database may not have run the migration properly.

## Solution: Run this on Railway

### Option 1: Via Railway Dashboard (Recommended)

1. Go to your Railway project dashboard
2. Click on your service
3. Go to "Settings" tab
4. Scroll to "Deploy" section
5. Click "Add variable" under "Deploy Command"
6. Add this one-time command:

```bash
rails runner "ActiveRecord::Base.connection.execute('CREATE UNIQUE INDEX IF NOT EXISTS index_ai_messages_on_id ON ai_messages (id);')"
```

### Option 2: Via Railway CLI

```bash
railway run rails runner "ActiveRecord::Base.connection.execute('CREATE UNIQUE INDEX IF NOT EXISTS index_ai_messages_on_id ON ai_messages (id);')"
```

### Option 3: Via Rails Console on Railway

1. Open Railway console:
```bash
railway run rails console
```

2. Run this:
```ruby
ActiveRecord::Base.connection.execute("CREATE UNIQUE INDEX IF NOT EXISTS index_ai_messages_on_id ON ai_messages (id);")
```

3. Verify:
```ruby
ActiveRecord::Base.connection.indexes('ai_messages').select { |i| i.columns == ['id'] && i.unique }
# Should return an index object
```

## Verification

After running the fix, verify it worked:

```bash
railway run rails runner "puts ActiveRecord::Base.connection.indexes('ai_messages').find { |i| i.columns == ['id'] && i.unique } ? '✅ Index exists' : '❌ Index missing'"
```

You should see: `✅ Index exists`

## Alternative: Force Migration Re-run

If the above doesn't work, force all migrations to re-run:

```bash
railway run rails db:migrate:redo VERSION=20260405155430
```

This will re-run the `AddUniqueIndexToAiMessagesId` migration.
