# Filament Panel RBAC

Every Filament panel declares its identifier and switcher label as constants, has a matching permission and role, and gates entry through `canAccessPanel()`.

A panel without a declared identifier is invisible to the code that builds the panel switcher, seeds roles, or asserts access in tests — each of those ends up hard-coding
the same string, and the fourth one gets it wrong. Binding the panel to a permission and role at declaration time means access is data the system can enumerate and seed,
not a condition scattered across providers.

**Rules:**

- Every panel provider declares a panel-id constant and a human-facing switcher-label constant; no inline string identifiers anywhere else.
- Every panel has a matching permission and role, declared as enum members — see [Authorization Identifier Naming](./authorization-identifier-naming.md).
- Panel entry is gated by the authenticatable model's `canAccessPanel()` checking that permission. No panel relies on route middleware alone.
- Adding a panel means: declare the constants, add the permission and role enum members, seed the role, gate `canAccessPanel()`, and add a feature test asserting both an
  allowed and a forbidden actor.
- Resources and pages inside a panel authorize per-action; panel access is a gate, not the authorization model.
- {{GEN:name the panel provider base class, the permission/role enums, and the seeding entry point this project uses, plus where panels live given {{MODULE_LAYOUT}}.
  Detect and confirm.}}

**Example:**

```php
// Bad — inline panel id, no permission, access decided by middleware alone
public function panel(Panel $panel): Panel
{
    return $panel->id('billing')->path('billing')->middleware([Authenticate::class]);
}

// Good — declared constants, permission-gated entry
public const PANEL_ID = 'billing';
public const SWITCHER_LABEL = 'Billing';

public function panel(Panel $panel): Panel
{
    return $panel->id(self::PANEL_ID)->path(self::PANEL_ID);
}

// the permission is a declared enum member, not a string built at the call site
enum PanelPermission: string
{
    case BillingAccess = 'panel:billing:access';

    public static function forPanel(Panel $panel): self
    {
        return match ($panel->getId()) {
            BillingPanelProvider::PANEL_ID => self::BillingAccess,
        };
    }
}

// on the authenticatable model
public function canAccessPanel(Panel $panel): bool
{
    return $this->hasPermission(PanelPermission::forPanel($panel));
}
```

> Severity for plan review: **BLOCK**.
