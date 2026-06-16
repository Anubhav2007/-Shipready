# Frontend Dimension — shipready v1.0.0

> **Max points: 15** | This dimension covers UI completeness, component architecture, accessibility, form handling, and the three non-negotiable states every UI surface must implement. A perfect Frontend score means any user — on any device, with any assistive technology — can complete every core workflow without encountering a dead end, a broken state, or an inaccessible interaction.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| All three states (loading / error / empty) on every list/data surface | 4 | Any surface missing any of the three |
| Forms: validation, feedback, all three form states | 3 | Uncontrolled inputs, missing error messages, no submission state |
| Accessibility (ARIA, keyboard nav, focus management) | 3 | Missing roles, no keyboard nav, invisible focus |
| Component architecture (reusable UI layer) | 3 | No shared components, logic in pages, no variant system |
| `not-found.tsx` and `error.tsx` required | 2 | Either missing |

---

## Rule 1 — The Three States (non-negotiable on every data surface)

Every component that fetches, displays, or waits for data MUST implement all three states. No exceptions. Missing any single state on any surface is a scoring deduction.

### State 1 — Loading

**When:** Data is being fetched, a mutation is in flight, or the page is transitioning.

**Requirements:**
- Use skeleton components that match the shape of the real content. A skeleton must approximate the size and layout of the loaded content — not a generic spinner in an empty box.
- Never use a full-page spinner for partial data refreshes. Scope the skeleton to the loading region only.
- Loading skeletons MUST have `animate-pulse` (Tailwind) or equivalent animation to signal activity.
- Use `loading.tsx` for route-level loading states (Next.js App Router convention).
- For server components, wrap suspense boundaries around async data fetching.

**Standard skeleton component:**
```typescript
// src/components/ui/Skeleton.tsx
import { cn } from '@/lib/utils'

interface SkeletonProps {
  className?: string
}

export function Skeleton({ className }: SkeletonProps) {
  return (
    <div
      className={cn('animate-pulse rounded-md bg-muted', className)}
      aria-hidden="true"
    />
  )
}

// Usage — match the real card's shape exactly:
export function BookingCardSkeleton() {
  return (
    <div className="rounded-lg border p-4 space-y-3">
      <Skeleton className="h-5 w-3/4" />
      <Skeleton className="h-4 w-1/2" />
      <div className="flex gap-2 pt-2">
        <Skeleton className="h-8 w-20" />
        <Skeleton className="h-8 w-16" />
      </div>
    </div>
  )
}
```

**Standard `loading.tsx`:**
```typescript
// src/app/(dashboard)/bookings/loading.tsx
import { BookingCardSkeleton } from '@/components/bookings/BookingCardSkeleton'

export default function BookingsLoading() {
  return (
    <div className="space-y-4" aria-label="Loading bookings">
      {Array.from({ length: 5 }).map((_, i) => (
        <BookingCardSkeleton key={i} />
      ))}
    </div>
  )
}
```

---

### State 2 — Error

**When:** A fetch fails, a mutation returns an error, or an unexpected exception occurs.

**Requirements:**
- Every error state MUST show a human-readable message (not "An error occurred" or the raw error message from the API).
- Every error state MUST show an actionable recovery path — a "Try again" button that re-triggers the fetch, or a "Go back" link.
- Use `error.tsx` for route-level error boundaries (must be a client component with `'use client'`).
- Never expose technical error details (stack traces, database errors, API error codes) in the UI. Log them server-side with Pino.
- Error messages must be distinct per context: "Could not load your bookings" is better than "Something went wrong."

**Standard `error.tsx`:**
```typescript
// src/app/error.tsx
'use client'

import { useEffect } from 'react'
import { Button } from '@/components/ui/Button'
import { logger } from '@/lib/logger'

interface ErrorProps {
  error: Error & { digest?: string }
  reset: () => void
}

export default function GlobalError({ error, reset }: ErrorProps) {
  useEffect(() => {
    logger.error({ err: error, digest: error.digest }, 'Unhandled route error')
  }, [error])

  return (
    <div
      role="alert"
      className="flex flex-col items-center justify-center min-h-[400px] gap-4 text-center"
    >
      <div className="rounded-full bg-destructive/10 p-4">
        <svg className="h-8 w-8 text-destructive" /* icon */ />
      </div>
      <h2 className="text-xl font-semibold">Something went wrong</h2>
      <p className="text-muted-foreground max-w-md">
        We couldn&apos;t load this page. The team has been notified.
      </p>
      <Button onClick={reset} variant="outline">Try again</Button>
    </div>
  )
}
```

**Standard inline error state (for data components):**
```typescript
// src/components/ui/ErrorState.tsx
import { Button } from './Button'

interface ErrorStateProps {
  title?: string
  message?: string
  onRetry?: () => void
}

export function ErrorState({
  title = 'Could not load data',
  message = 'There was a problem fetching this information. Please try again.',
  onRetry,
}: ErrorStateProps) {
  return (
    <div role="alert" className="flex flex-col items-center gap-3 py-12 text-center">
      <p className="font-medium text-destructive">{title}</p>
      <p className="text-sm text-muted-foreground max-w-xs">{message}</p>
      {onRetry && (
        <Button variant="outline" size="sm" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  )
}
```

---

### State 3 — Empty

**When:** A fetch succeeds but returns zero items, or a user has not yet created any records.

**Requirements:**
- Empty state MUST be context-aware. "No bookings yet" is better than "No results."
- Empty state MUST include a call to action that takes the user to the creation flow.
- Empty state MUST NOT look like an error. Use a softer visual treatment (illustration, icon, neutral text).
- Do not render an empty `<ul>` or a blank `<div>`. Render the empty state component explicitly when `items.length === 0`.

**Standard `EmptyState` component:**
```typescript
// src/components/ui/EmptyState.tsx
import { Button } from './Button'
import Link from 'next/link'

interface EmptyStateProps {
  icon?: React.ReactNode
  title: string
  description: string
  action?: {
    label: string
    href?: string
    onClick?: () => void
  }
}

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
      {icon && (
        <div className="mb-4 rounded-full bg-muted p-4 text-muted-foreground">
          {icon}
        </div>
      )}
      <h3 className="text-lg font-semibold">{title}</h3>
      <p className="mt-1 text-sm text-muted-foreground max-w-sm">{description}</p>
      {action && (
        <div className="mt-6">
          {action.href ? (
            <Button asChild>
              <Link href={action.href}>{action.label}</Link>
            </Button>
          ) : (
            <Button onClick={action.onClick}>{action.label}</Button>
          )}
        </div>
      )}
    </div>
  )
}
```

**Usage:**
```typescript
{bookings.length === 0 ? (
  <EmptyState
    icon={<CalendarIcon className="h-6 w-6" />}
    title="No bookings yet"
    description="Reserve your first table and it will appear here."
    action={{ label: 'Make a booking', href: '/bookings/new' }}
  />
) : (
  <BookingList bookings={bookings} />
)}
```

---

## Rule 2 — Forms (react-hook-form + Zod, three form states)

### Architecture requirements

- All forms MUST use `react-hook-form` with the `zodResolver`.
- The Zod schema used for form validation MUST be shared with the API route's input validation. One source of truth.
- Forms MUST be controlled — no uncontrolled inputs. Use `register()` or `<Controller>` for every field.
- Form state MUST never be managed with `useState` directly for field values.

### The three form states

Every form must implement:

| State | Visual requirement |
|---|---|
| **Idle** | Default state. All fields enabled. Submit button shows label. |
| **Submitting** | Submit button shows spinner + "Saving..." text. All fields disabled. Prevents double submission. |
| **Error** | Field-level errors shown inline below each field. Form-level errors shown in an `<Alert>` above the submit button. |

**Standard form implementation:**
```typescript
// src/components/forms/CreateBookingForm.tsx
'use client'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { createBookingSchema } from '@/lib/validations/booking'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Alert } from '@/components/ui/Alert'
import { useState } from 'react'

type CreateBookingInput = z.infer<typeof createBookingSchema>

export function CreateBookingForm() {
  const [serverError, setServerError] = useState<string | null>(null)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<CreateBookingInput>({
    resolver: zodResolver(createBookingSchema),
  })

  async function onSubmit(data: CreateBookingInput) {
    setServerError(null)
    try {
      const response = await fetch('/api/v1/bookings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      })
      if (!response.ok) {
        const err = await response.json()
        setServerError(err.error ?? 'Failed to create booking. Please try again.')
        return
      }
      reset()
      // navigate or show success toast
    } catch {
      setServerError('Network error. Please check your connection and try again.')
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate className="space-y-4">
      {serverError && (
        <Alert variant="destructive" role="alert">
          {serverError}
        </Alert>
      )}

      <div>
        <label htmlFor="guestName" className="text-sm font-medium">
          Guest name <span aria-hidden="true">*</span>
        </label>
        <Input
          id="guestName"
          {...register('guestName')}
          disabled={isSubmitting}
          aria-describedby={errors.guestName ? 'guestName-error' : undefined}
          aria-invalid={!!errors.guestName}
        />
        {errors.guestName && (
          <p id="guestName-error" className="text-sm text-destructive mt-1" role="alert">
            {errors.guestName.message}
          </p>
        )}
      </div>

      <Button type="submit" disabled={isSubmitting} className="w-full">
        {isSubmitting ? (
          <>
            <span className="animate-spin mr-2" aria-hidden="true">⟳</span>
            Saving...
          </>
        ) : (
          'Create booking'
        )}
      </Button>
    </form>
  )
}
```

### Delete confirmation pattern

All destructive actions MUST use a confirmation modal. Never delete on first click.

```typescript
// Pattern for delete with confirmation
const [deleteTarget, setDeleteTarget] = useState<string | null>(null)

// Trigger:
<Button variant="destructive" onClick={() => setDeleteTarget(item.id)}>
  Delete
</Button>

// Confirmation modal must:
// 1. State exactly what will be deleted ("Delete booking #1234?")
// 2. Warn about irreversibility ("This cannot be undone.")
// 3. Have a clearly secondary cancel action
// 4. Show loading state on confirm button during deletion
```

---

## Rule 3 — Accessibility

Accessibility is not a post-launch concern. Every component must be accessible from line one.

### Required for every interactive element

| Element | Requirements |
|---|---|
| Buttons | Descriptive `aria-label` if icon-only. Never use a `<div>` as a button. |
| Inputs | Always paired with a `<label>`. Connected via `htmlFor` ↔ `id`. `aria-describedby` pointing to error message ID. `aria-invalid` when in error state. |
| Modals | `role="dialog"`, `aria-modal="true"`, `aria-labelledby` pointing to modal title ID. Focus trapped inside while open. Returns focus to trigger on close. |
| Loading states | `aria-live="polite"` region for dynamic content updates. `aria-busy="true"` on the loading container. |
| Error messages | `role="alert"` for server-level errors (triggers screen reader announcement). Field errors use `aria-describedby`. |
| Icons (decorative) | `aria-hidden="true"`. |
| Icons (meaningful) | `aria-label` on the icon or its parent button. |
| Tables | `<thead>`, `<th scope="col">`, `<caption>` or `aria-label` on `<table>`. |
| Navigation | `<nav aria-label="Main navigation">`. Current page link has `aria-current="page"`. |

### Keyboard navigation requirements

- All interactive elements reachable with Tab.
- Modals trap focus (Tab cycles within the modal).
- Dropdown menus navigable with arrow keys, closed with Escape.
- Forms submittable with Enter on any field.
- Custom interactive components (carousels, tabs, accordions) follow ARIA Authoring Practices Guide patterns.

### Focus visibility

- Never remove the default browser focus ring without replacing it. Use `focus-visible:ring-2 focus-visible:ring-ring` (Tailwind) on all interactive elements.
- Focus ring must be visible against both light and dark backgrounds.

### Color contrast

- Text: minimum 4.5:1 contrast ratio against background (WCAG AA).
- UI components (buttons, inputs, borders): minimum 3:1.
- Never convey information with color alone. Pair color with an icon or text label.

### Reduced motion

```css
/* In globals.css */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## Rule 4 — Component Architecture

### Directory structure

```
src/components/
├── ui/               # Primitive, reusable, context-free components
│   ├── Button.tsx
│   ├── Input.tsx
│   ├── Select.tsx
│   ├── Modal.tsx
│   ├── Toast.tsx
│   ├── Badge.tsx
│   ├── Skeleton.tsx
│   ├── Pagination.tsx
│   ├── EmptyState.tsx
│   ├── ErrorState.tsx
│   ├── Alert.tsx
│   └── Spinner.tsx
├── forms/            # Feature-specific form components
│   └── [Feature]Form.tsx
└── [feature]/        # Feature-specific display components
    └── [Feature]Card.tsx
    └── [Feature]List.tsx
```

### Component rules

- `ui/` components MUST have zero business logic. They render what they receive via props. No `fetch` calls. No routing. No feature-specific state.
- Feature components live in `components/[feature]/` and MAY contain feature-specific logic.
- Pages (`app/*/page.tsx`) orchestrate data fetching and compose feature components. They do NOT contain JSX business logic beyond layout.
- Every `ui/` component MUST support a `className` prop for layout overrides (use `cn()` from `class-variance-authority`).

### Button variant system

```typescript
// src/components/ui/Button.tsx
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'
import { forwardRef } from 'react'

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => (
    <button
      ref={ref}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
)
Button.displayName = 'Button'
```

### Pagination component

Required on every list that can have more than 20 records.

```typescript
// src/components/ui/Pagination.tsx
interface PaginationProps {
  currentPage: number
  totalPages: number
  onPageChange: (page: number) => void
}

export function Pagination({ currentPage, totalPages, onPageChange }: PaginationProps) {
  if (totalPages <= 1) return null

  return (
    <nav aria-label="Pagination" className="flex items-center justify-center gap-2">
      <button
        onClick={() => onPageChange(currentPage - 1)}
        disabled={currentPage === 1}
        aria-label="Previous page"
        className="..."
      >
        Previous
      </button>
      <span aria-current="page" className="text-sm">
        Page {currentPage} of {totalPages}
      </span>
      <button
        onClick={() => onPageChange(currentPage + 1)}
        disabled={currentPage === totalPages}
        aria-label="Next page"
        className="..."
      >
        Next
      </button>
    </nav>
  )
}
```

---

## Rule 5 — `not-found.tsx` and `error.tsx`

Both files are mandatory in every generated app. Skipping either is a guaranteed deduction.

### `not-found.tsx`

```typescript
// src/app/not-found.tsx
import Link from 'next/link'
import { Button } from '@/components/ui/Button'

export default function NotFound() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 text-center p-4">
      <h1 className="text-6xl font-bold text-muted-foreground">404</h1>
      <h2 className="text-2xl font-semibold">Page not found</h2>
      <p className="text-muted-foreground max-w-md">
        The page you&apos;re looking for doesn&apos;t exist or has been moved.
      </p>
      <Button asChild>
        <Link href="/">Back to home</Link>
      </Button>
    </main>
  )
}
```

### `error.tsx` rules

- Must be a client component (`'use client'` at the top).
- Must accept `error` and `reset` props.
- Must call `reset()` when the user clicks "Try again".
- Must log the error (in a `useEffect`) without exposing it in the UI.
- See Rule 1 (Error state) for the full implementation template.

---

## Deductions reference (Frontend)

| Violation | Deduction |
|---|---|
| Any list/data surface missing loading state | -2 per surface |
| Any list/data surface missing error state | -2 per surface |
| Any list/data surface missing empty state | -1 per surface |
| Form missing any of the three form states | -1 per missing state |
| Destructive action without confirmation | -1 per action |
| Missing `aria-label` on icon-only button | -1 per button |
| Input not associated with a label | -1 per input |
| Modal without focus trap | -2 |
| `not-found.tsx` missing | -2 |
| `error.tsx` missing | -2 |
| Pagination missing on a list that could exceed 20 records | -2 |
| `console.log` in a client component | -1 per instance |
| Hardcoded placeholder text ("Lorem ipsum") | -1 per instance |
| No `focus-visible` styles on interactive elements | -1 |

---

## Checklist (use before scoring)

- [ ] Every list page has a skeleton loading state (`loading.tsx` or Suspense fallback)
- [ ] Every list page has an error state with a retry action
- [ ] Every list page has an empty state with a call to action
- [ ] All forms use `react-hook-form` + `zodResolver`
- [ ] All forms show field-level error messages below each invalid field
- [ ] Submit button shows spinner and is disabled during submission
- [ ] All destructive actions require a confirmation modal
- [ ] Every input has a connected `<label>`
- [ ] Every icon-only button has `aria-label`
- [ ] Error messages have `role="alert"`
- [ ] Loading containers have `aria-busy="true"`
- [ ] `not-found.tsx` exists with a link back to home
- [ ] `error.tsx` exists as a client component with `reset` functionality
- [ ] `Skeleton`, `EmptyState`, `ErrorState`, `Button`, `Pagination` all exist in `components/ui/`
- [ ] Pagination renders on every list that may exceed 20 items
- [ ] `prefers-reduced-motion` respected in CSS
- [ ] No Lorem Ipsum or placeholder copy in any page

---

*Frontend dimension — shipready v1.0.0*