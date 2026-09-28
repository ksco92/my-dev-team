# React/TypeScript Coding Standards Guide

This document defines the React/TypeScript coding standards for Rodrigo's projects. These
standards are enforced through ESLint and TypeScript strict mode.

---

## Table of Contents

1. [General Coding Standards](#general-coding-standards)
2. [Component Standards](#component-standards)
3. [Service Standards](#service-standards)
4. [Unit Testing Standards](#unit-testing-standards)

---

## General Coding Standards

### Module Structure

Each file should contain exactly one component, service, or utility. Name the file after its
default export using PascalCase for components/services and camelCase for utilities.

### Imports

Organize imports into three groups separated by blank lines:

1. **React and React-related** (`react`, `react-dom`, `react-router-dom`)
2. **Third-party libraries** (`@mui/material`, `axios`, `react-select`)
3. **Local imports** (components, services, utils)

Each import group must have its destructured items on separate lines when importing multiple
items (enforced by `object-curly-newline` rule with `minProperties: 1`).

**Example:**

```typescript
import React, {
    useEffect,
    useState,
} from 'react';

import {
    Box,
    Button,
    Typography,
} from '@mui/material';

import api from '../services/api';
import LoadingWheel from '../components/LoadingWheel';
```

### TypeScript Strict Mode

All projects use TypeScript with `strict: true`. This means:

- All variables must be typed or inferable
- No implicit `any`
- Strict null checks enabled
- No unused locals or parameters (unused params prefixed with `_` are allowed)

### Documentation (JSDoc)

Every function and component must have a JSDoc docstring.

**Function documentation:**

```typescript
/**
 * Fetch the list of allergens from the backend.
 * @param includeInactive Whether to include inactive allergens.
 * @returns A promise resolving to an array of Allergen objects.
 */
const fetchAllergens = async (includeInactive: boolean): Promise<Allergen[]> => {
    // implementation
};
```

**Interface documentation:**

```typescript
export interface Allergen {
    /** Unique identifier for the allergen. */
    id: number;

    /** Display name of the allergen (e.g., "Peanuts"). */
    name: string;

    /**
     * Whether the allergen is currently active.
     * @default true
     */
    isActive?: boolean;
}
```

**Component documentation:**

```typescript
/**
 * Display a loading spinner centered in the viewport.
 */
const LoadingWheel = (): JSX.Element => {
    // implementation
};
```

### Formatting Rules

These rules are enforced by the ESLint configuration (`eslint.config.mjs`):

#### Indentation

4 spaces. Never tabs.

#### Quotes

Single quotes for all strings. Template literals are allowed. Use `avoidEscape` to avoid
escaping single quotes inside strings.

```typescript
// Correct
const name = 'AllerShare';
const greeting = `Hello, ${name}!`;
const message = "It's a sunny day";

// Incorrect
const name = "AllerShare";
```

#### Trailing Commas

Required in multiline arrays, objects, imports, and exports. Not enforced on function
parameters.

```typescript
// Correct
const allergens = [
    'Peanuts',
    'Shellfish',
    'Dairy',
];

// Incorrect
const allergens = [
    'Peanuts',
    'Shellfish',
    'Dairy'
];
```

#### Multiline Arrays and Objects

Arrays and objects with one or more elements must have each element on its own line.

```typescript
// Correct
const config = {
    baseURL: 'http://localhost:8000',
    timeout: 5000,
};

// Incorrect
const config = { baseURL: 'http://localhost:8000', timeout: 5000 };
```

#### Object Property Newlines

Each property in an object literal must be on its own line. No exceptions.

#### Quote Props

Object property names are only quoted when necessary (e.g., `'Content-Type'`).

#### Unused Variables

Unused variables are flagged as errors. Prefix intentionally unused parameters with `_`:

```typescript
const handleClick = (_event: React.MouseEvent): void => {
    // event not used
};
```

### Comments

- Write comments only when the logic is not self-evident.
- JSDoc and comments follow the budget in `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` (Comment,
  docstring, and helper budget): contract plus at most one constraint; no test evidence or
  rationale essays; a one-statement helper with one call site is inlined.
- Do not leave placeholder comments like `// Add this line` or `// NEW`.
- Never remove multiline comment separators (`/// //////....`) used for readability.
- Use a developer-friendly, concise tone.

### Error Handling

- Wrap async operations in try-catch blocks.
- Show user-facing error messages via MUI components (Snackbar, Alert, helper text).
- Log errors with `console.error` for debugging.
- Never swallow errors silently.

---

## Component Standards

### Functional Components Only

Use functional components with hooks. Never use class components.

```typescript
/**
 * Display the user's profile information.
 */
const ProfilePage = (): JSX.Element => {
    const [
        loading,
        setLoading,
    ] = useState<boolean>(true);

    // implementation

    return <Box>...</Box>;
};

export default ProfilePage;
```

### Props Interfaces

Define a typed interface for component props. Document each prop with JSDoc.

```typescript
/** Props for the AllergiesTable component. */
interface AllergiesTableProps {
    /** List of user allergies to display. */
    allergies: UserAllergy[];

    /** Available intolerance levels for the dropdown. */
    levels: IntoleranceLevel[];

    /** Callback fired when the user changes an allergy's intolerance level. */
    onLevelChange: (allergyId: number, newLevelId: number) => void;

    /** Callback fired when the user deletes an allergy. */
    onDelete: (allergyId: number) => void;
}
```

### Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Component files | PascalCase | `ProfilePage.tsx` |
| Component names | PascalCase | `ProfilePage` |
| Service files | PascalCase | `GroupService.tsx` |
| Utility files | camelCase | `csrf.ts` |
| Functions | camelCase | `fetchAllergens` |
| Variables | camelCase | `isLoading` |
| Interfaces/Types | PascalCase | `UserAllergy` |
| Constants | UPPER_SNAKE_CASE | `API_BASE_URL` |
| CSS class names | camelCase (via MUI `sx`) | N/A (no CSS files) |

### Styling

Use MUI's `sx` prop for all styling. No separate CSS/SCSS files.

```typescript
<Box sx={{
    display: 'flex',
    justifyContent: 'center',
    p: 2,
}}>
```

Use the MUI theme for colors and spacing. Access via `useTheme()` or `theme` prop when
needed.

---

## Service Standards

### One Service Per Domain Entity

Each backend resource gets its own service file:

- `GroupService.tsx` — Group CRUD
- `UserAllergyService.tsx` — User allergy CRUD
- `DietaryPreferenceService.tsx` — Dietary preference CRUD

### Service Structure

Services export an object with async methods that return typed Promises. All API calls go
through the centralized Axios instance from `api.ts`.

```typescript
import api from './api';

/** Response shape for an Allergen from the backend. */
interface Allergen {
    /** Unique identifier. */
    id: number;

    /** Display name. */
    name: string;
}

/**
 * Service for allergen API operations.
 */
const AllergenService = {
    /**
     * Fetch all allergens.
     * @returns A promise resolving to an array of allergens.
     */
    listAllergens: async (): Promise<Allergen[]> => {
        const response = await api.get('/allergens/');
        return response.data;
    },
};

export default AllergenService;
```

### CSRF and Authentication

The Axios instance in `api.ts` handles CSRF token injection and `withCredentials: true`
automatically. Services do not need to manage authentication headers.

---

## Unit Testing Standards

### Test Framework

Use **Jest** (via react-scripts) and **React Testing Library** for all tests.

### Test File Structure

Test files live in `src/tests/` and mirror the source structure:

```
src/
├── pages/
│   ├── ProfilePage.tsx
│   └── GroupPage.tsx
├── services/
│   └── GroupService.tsx
└── tests/
    ├── pages/
    │   ├── ProfilePage.test.tsx
    │   └── GroupPage.test.tsx
    └── services/
        └── GroupService.test.tsx
```

### Test File Naming

- Test files: `*.test.tsx` or `*.test.ts`
- Name matches the source file: `GroupService.tsx` → `GroupService.test.tsx`

### Test Structure

```typescript
import {
    render,
    screen,
} from '@testing-library/react';

import ProfilePage from '../../pages/ProfilePage';

/**
 * Test that the profile page renders the loading spinner initially.
 */
test('renders loading spinner on mount', () => {
    render(<ProfilePage />);
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
});
```

### Mocking API Calls

Mock the API module at the top of the test file:

```typescript
import api from '../../services/api';

jest.mock('../../services/api');
const mockedAPI = api as jest.Mocked<typeof api>;

test('fetches allergens on mount', async () => {
    mockedAPI.get.mockResolvedValueOnce({
        data: [
            {
                id: 1,
                name: 'Peanuts',
            },
        ],
    });

    // render and assert
});
```

### Test Assertions

- Use `expect(...).toBeInTheDocument()` for DOM presence.
- Use `expect(...).toHaveBeenCalledWith(...)` for function call verification.
- Use `waitFor(() => ...)` for async assertions.
- Use `screen.getByRole`, `screen.getByText`, `screen.getByTestId` for queries.

---

## Linter Configuration

### ESLint 9 (Flat Config)

The project uses ESLint 9 with `@typescript-eslint`. The configuration is in
`eslint.config.mjs`.

### Enforced Rules Summary

| Rule | Setting | Description |
|---|---|---|
| `indent` | 4 spaces | Consistent indentation |
| `quotes` | single | Single quotes everywhere |
| `comma-dangle` | always-multiline | Trailing commas in multiline |
| `array-bracket-newline` | minItems: 1 | One element per line |
| `array-element-newline` | minItems: 1 | One element per line |
| `object-curly-newline` | minProperties: 1 | One property per line |
| `object-property-newline` | no same line | One property per line |
| `quote-props` | as-needed | Quote only when required |
| `@typescript-eslint/no-unused-vars` | error, ignore `_` | No unused variables |

### Running the Linter

```bash
npm run lint
```

This runs ESLint with `--fix` on `src/` and `eslint.config.mjs` itself.

---

## Summary

### Key Principles

1. **Type everything**: Strict TypeScript, no implicit `any`
2. **Document everything**: JSDoc on all functions, interfaces, and components
3. **Test everything**: Jest + React Testing Library, mirror source structure
4. **Format consistently**: 4 spaces, single quotes, trailing commas, multiline everything
5. **Follow the linter**: Do not fight ESLint's rules
6. **One thing per file**: One component, service, or utility per file
7. **MUI for styling**: No CSS files, use `sx` prop and theme

### Enforcement

These standards are enforced through:

- **ESLint 9**: Style checking with `@typescript-eslint`
- **TypeScript**: Strict mode type checking
- **Jest**: Testing with coverage reporting

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in
any repo of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an
imperative bullet under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after" tail),
refine near-duplicates in place, keep the section under ~25 entries, and open a PR against the
plugin repository (`ksco92/my-dev-team`).

## Learned patterns

- A `useIsMounted`-style ref guard sets `current = true` inside the effect body, never only at
  `useRef(true)`: StrictMode's mount/cleanup/re-run leaves a cleanup-only design permanently false
  and every guarded setState skips. Add one regression test rendering the consuming page inside
  `<React.StrictMode>`, and prefer closure-scoped per-effect ignore flags where one effect is
  guarded.
- In `@playwright/test`, `browser.newContext()` merges the project's `use` options including
  `storageState`, so an "anonymous" context inside a signed-in project starts authenticated; pass
  `storageState: { cookies: [], origins: [] }` explicitly and prove anonymity from the trace's
  request cookies. An E2E helper that triggers a re-rendering mutation ends on a deterministic
  settle point (the new entity's locator) before returning.
- A heavily-async e2e helper that awaits `page.waitForResponse` must check `response.ok()`; unchecked, a 4xx becomes a locator timeout tens of lines away, and from a `finally` it discards the test's real failure.
