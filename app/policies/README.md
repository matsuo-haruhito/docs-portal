# Pundit Policies

このディレクトリは Pundit の policy 置き場です。

- policy は controller や view から `authorize` / `policy` / `policy_scope` で呼べます。
- この repo では、複雑な権限ロジック本体は model や concern に寄せ、policy はその問い合わせ窓口として薄く保つ方針です。
- 迷ったら、まず model に `viewable_by?` `downloadable_by?` のような意図が読めるメソッドを置き、policy からそれを呼んでください。

例:

```ruby
class DocumentVersionPolicy < ApplicationPolicy
  def show?
    record.viewable_by?(user)
  end
end
```
