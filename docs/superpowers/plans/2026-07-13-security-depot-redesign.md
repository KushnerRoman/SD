# Security Depot Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a polished six-route Security Depot website that turns residential, commercial, and condominium visitors into security-assessment leads.

**Architecture:** Create a new Sites/Vinext application in `app/security_depot_web` so the existing Flutter field-service application remains untouched. Route files compose focused shared components and typed content; interactive product filtering and the assessment wizard are isolated client components, while marketing pages remain server-rendered.

**Tech Stack:** TypeScript, React, Vinext/Next-compatible App Router, CSS, Lucide React, Vitest, Testing Library, Sites hosting.

## Global Constraints

- The primary conversion action is labelled **Request Assessment** on every route.
- Routes are `/`, `/residential`, `/commercial`, `/condominiums`, `/products`, and `/contact`.
- Use Security Depot's public facts without inventing certifications, customer counts, response-time guarantees, pricing, monitoring claims, or product partnerships.
- The palette is near-black graphite, steel grey, electric cyan, and restrained healthy-state green.
- Avoid generic hacker imagery; the tone is advanced, calm, capable, and trustworthy.
- Honor `prefers-reduced-motion`, maintain strong contrast, and support keyboard, pointer, and touch input.
- The assessment is a local demonstration only and must never claim that a live request was transmitted.
- Do not add authentication, payments, checkout, a database, or CRM integration.

---

## Planned File Map

- `app/security_depot_web/app/layout.tsx` — metadata, fonts, and shared site shell
- `app/security_depot_web/app/globals.css` — tokens, responsive layout, motion, and component styling
- `app/security_depot_web/app/page.tsx` — home route composition
- `app/security_depot_web/app/{residential,commercial,condominiums,products,contact}/page.tsx` — remaining route compositions
- `app/security_depot_web/app/_components/site-header.tsx` — navigation and mobile menu
- `app/security_depot_web/app/_components/site-footer.tsx` — business details and route links
- `app/security_depot_web/app/_components/surveillance-hero.tsx` — animated hero viewport
- `app/security_depot_web/app/_components/solution-page.tsx` — reusable audience-page presentation
- `app/security_depot_web/app/_components/product-explorer.tsx` — filterable, expandable product catalog
- `app/security_depot_web/app/_components/assessment-wizard.tsx` — multi-step assessment flow
- `app/security_depot_web/app/_components/assessment-cta.tsx` — reusable conversion band
- `app/security_depot_web/app/_lib/content.ts` — typed navigation, solution, product, and business content
- `app/security_depot_web/app/_lib/assessment.ts` — assessment state and pure validation
- `app/security_depot_web/app/_lib/assessment.test.ts` — validation tests
- `app/security_depot_web/app/_components/product-explorer.test.tsx` — filter and disclosure tests
- `app/security_depot_web/app/_components/assessment-wizard.test.tsx` — wizard behavior tests
- `app/security_depot_web/public/og.png` — generated, verified social preview image

### Task 1: Create the Isolated Web Application and Content Contracts

**Files:**
- Create: `app/security_depot_web/**` using the Sites initializer
- Create: `app/security_depot_web/app/_lib/content.ts`
- Create: `app/security_depot_web/app/_lib/assessment.ts`
- Create: `app/security_depot_web/app/_lib/assessment.test.ts`
- Modify: `app/security_depot_web/package.json`

**Interfaces:**
- Produces: `NavItem`, `AudienceKey`, `SolutionPageContent`, `ProductCategory`, `Product`, `AssessmentData`, `validateAssessmentStep(step, data)`
- Consumes: none

- [ ] **Step 1: Initialize the new site once**

Run the Sites initializer with `app/security_depot_web` as the target, keep its package manager and lockfile, and start its development server. Confirm the printed local URL loads the starter.

- [ ] **Step 2: Add the test dependencies and scripts**

Add `vitest`, `jsdom`, `@testing-library/react`, `@testing-library/jest-dom`, and `@testing-library/user-event`. Add scripts:

```json
{
  "test": "vitest run",
  "test:watch": "vitest"
}
```

- [ ] **Step 3: Write the failing assessment validation test**

```ts
import { describe, expect, it } from "vitest";
import { EMPTY_ASSESSMENT, validateAssessmentStep } from "./assessment";

describe("validateAssessmentStep", () => {
  it("requires property type on step 0", () => {
    expect(validateAssessmentStep(0, EMPTY_ASSESSMENT)).toEqual({
      propertyType: "Choose a property type.",
    });
  });

  it("requires a concern on step 1", () => {
    expect(validateAssessmentStep(1, { ...EMPTY_ASSESSMENT, propertyType: "commercial" })).toEqual({
      concerns: "Select at least one security concern.",
    });
  });

  it("validates contact details on step 3", () => {
    const errors = validateAssessmentStep(3, EMPTY_ASSESSMENT);
    expect(errors.name).toBe("Enter your name.");
    expect(errors.email).toBe("Enter a valid email address.");
    expect(errors.phone).toBe("Enter a phone number.");
  });
});
```

- [ ] **Step 4: Run the test and confirm the expected failure**

Run: `npm test -- app/_lib/assessment.test.ts`

Expected: FAIL because `EMPTY_ASSESSMENT` and `validateAssessmentStep` do not exist.

- [ ] **Step 5: Implement the assessment contracts and validation**

```ts
export type PropertyType = "" | "residential" | "commercial" | "condominium";
export type Timeline = "" | "urgent" | "30-days" | "planning";
export type ContactMethod = "phone" | "email";

export interface AssessmentData {
  propertyType: PropertyType;
  concerns: string[];
  timeline: Timeline;
  name: string;
  email: string;
  phone: string;
  contactMethod: ContactMethod;
}

export type AssessmentErrors = Partial<Record<keyof AssessmentData, string>>;

export const EMPTY_ASSESSMENT: AssessmentData = {
  propertyType: "",
  concerns: [],
  timeline: "",
  name: "",
  email: "",
  phone: "",
  contactMethod: "phone",
};

export function validateAssessmentStep(step: number, data: AssessmentData): AssessmentErrors {
  if (step === 0 && !data.propertyType) return { propertyType: "Choose a property type." };
  if (step === 1 && data.concerns.length === 0) return { concerns: "Select at least one security concern." };
  if (step === 2 && !data.timeline) return { timeline: "Choose a project timeline." };
  if (step === 3) {
    const errors: AssessmentErrors = {};
    if (!data.name.trim()) errors.name = "Enter your name.";
    if (!/^\S+@\S+\.\S+$/.test(data.email)) errors.email = "Enter a valid email address.";
    if (data.phone.replace(/\D/g, "").length < 10) errors.phone = "Enter a phone number.";
    return errors;
  }
  return {};
}
```

- [ ] **Step 6: Define typed content**

Create exported `NAV_ITEMS`, `BUSINESS`, `SOLUTION_PAGES`, and `PRODUCTS` constants. Use these exact business values: phone `403-250-5363`, address `Bay B5, 416 Meridian Road SE, Calgary, AB T2A 1X2`, and regions `Calgary`, `Airdrie`, `Canmore`, `Sundre`, `Chestermere`, `Okotoks`, and `Red Deer`. Define products for alarms, surveillance and recording, intercom and access control, gates and shutters, automation, security film, and secure storage.

- [ ] **Step 7: Run tests and commit**

Run: `npm test -- app/_lib/assessment.test.ts`

Expected: 3 tests pass.

Commit: `feat: scaffold Security Depot web experience`

### Task 2: Build the Accessible Command-Center Design System and Site Shell

**Files:**
- Modify: `app/security_depot_web/app/layout.tsx`
- Modify: `app/security_depot_web/app/globals.css`
- Create: `app/security_depot_web/app/_components/site-header.tsx`
- Create: `app/security_depot_web/app/_components/site-footer.tsx`
- Create: `app/security_depot_web/app/_components/assessment-cta.tsx`
- Delete: `app/security_depot_web/app/_sites-preview/**`

**Interfaces:**
- Consumes: `NAV_ITEMS`, `BUSINESS`
- Produces: `SiteHeader`, `SiteFooter`, `AssessmentCta`

- [ ] **Step 1: Replace starter metadata and preview UI**

Set the title template to `%s | Security Depot`, default title to `Security Depot | Integrated Security Systems`, and description to `Calgary security assessments, surveillance, access control, alarms, gates, and automation for homes, businesses, and condominiums.` Remove starter preview imports and files.

- [ ] **Step 2: Implement the shared shell**

`SiteHeader` must render all six routes, expose an accessible mobile-menu button with `aria-expanded`, highlight the current path, include a `tel:4032505363` link, and render the primary `/contact` action. `SiteFooter` must render business details, appointment note, regions, and route links. `AssessmentCta` accepts `{ eyebrow: string; title: string; copy: string }` and links to `/contact`.

- [ ] **Step 3: Implement global tokens and layouts**

Define CSS custom properties `--ink: #05090c`, `--panel: #0b1217`, `--steel: #8ea0ad`, `--text: #eef7fb`, `--cyan: #20d8ff`, `--cyan-soft: #8cecff`, `--healthy: #71f5ad`, and `--line: rgba(140,236,255,.16)`. Add focus-visible outlines, minimum 44px touch targets, responsive containers, cards, grids, buttons, status chips, scan-line utilities, and a reduced-motion media query that removes animation and smooth scrolling.

- [ ] **Step 4: Verify shell routes and commit**

Run: `npm run build`

Expected: build succeeds; all six navigation URLs are emitted without type errors.

Commit: `feat: add Security Depot visual system and navigation`

### Task 3: Create the Cinematic Home Experience

**Files:**
- Modify: `app/security_depot_web/app/page.tsx`
- Create: `app/security_depot_web/app/_components/surveillance-hero.tsx`

**Interfaces:**
- Consumes: `BUSINESS`, `SOLUTION_PAGES`, `AssessmentCta`
- Produces: `SurveillanceHero`

- [ ] **Step 1: Build the surveillance hero**

Create a client component that rotates every four seconds through `Perimeter / Secure`, `Entry / Verified`, and `Interior / Armed`, pauses when focused or hovered, exposes manual previous/next buttons, and stops automatic changes when reduced motion is active. Use CSS shapes, timestamps, reticles, and status labels; do not use model-authored SVG illustration.

- [ ] **Step 2: Compose the home route**

Use the headline `See every risk. Secure every layer.` and support it with the true `40+ years` experience statement. Add four linked solution cards, an integrated-system section, a three-step process (`Assess`, `Engineer`, `Protect`), the seven-region coverage list, and a final `AssessmentCta`.

- [ ] **Step 3: Verify responsive behavior and commit**

Run: `npm run build`

Expected: home route compiles; no missing imports or client/server boundary errors.

Commit: `feat: build cinematic Security Depot home page`

### Task 4: Build Residential, Commercial, and Condominium Solution Routes

**Files:**
- Create: `app/security_depot_web/app/_components/solution-page.tsx`
- Create: `app/security_depot_web/app/residential/page.tsx`
- Create: `app/security_depot_web/app/commercial/page.tsx`
- Create: `app/security_depot_web/app/condominiums/page.tsx`

**Interfaces:**
- Consumes: `SolutionPageContent`, `SOLUTION_PAGES`, `AssessmentCta`
- Produces: `SolutionPage({ content }: { content: SolutionPageContent })`

- [ ] **Step 1: Implement the reusable solution-page renderer**

Render an audience-specific hero, security challenges, integrated capabilities, a scenario panel, process steps, and a route-specific assessment CTA. Each capability card includes a name, concise description, and three concrete features sourced from `content.ts`.

- [ ] **Step 2: Compose the three route files**

Each route selects its own typed content and exports unique metadata. Residential emphasizes families and automation; Commercial emphasizes access, surveillance, gates, storage, and multi-site scale; Condominiums emphasizes residents, visitors, parking, common areas, and retrofit coordination.

- [ ] **Step 3: Verify all routes and commit**

Run: `npm run build`

Expected: `/residential`, `/commercial`, and `/condominiums` build successfully with distinct titles.

Commit: `feat: add audience security solution pages`

### Task 5: Create the Interactive Product Explorer

**Files:**
- Create: `app/security_depot_web/app/products/page.tsx`
- Create: `app/security_depot_web/app/_components/product-explorer.tsx`
- Create: `app/security_depot_web/app/_components/product-explorer.test.tsx`

**Interfaces:**
- Consumes: `Product`, `ProductCategory`, `PRODUCTS`
- Produces: `ProductExplorer({ products }: { products: Product[] })`

- [ ] **Step 1: Write failing interaction tests**

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { ProductExplorer } from "./product-explorer";

const products = [
  { id: "cam", category: "surveillance", name: "Camera Systems", summary: "Visible day and night.", features: ["Remote view"], uses: ["Perimeters"] },
  { id: "gate", category: "physical", name: "Security Gates", summary: "Control openings.", features: ["Custom fit"], uses: ["Storefronts"] },
] as const;

describe("ProductExplorer", () => {
  it("filters products and resets to all", async () => {
    const user = userEvent.setup();
    render(<ProductExplorer products={[...products]} />);
    await user.click(screen.getByRole("button", { name: "Surveillance" }));
    expect(screen.getByText("Camera Systems")).toBeInTheDocument();
    expect(screen.queryByText("Security Gates")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "All systems" }));
    expect(screen.getByText("Security Gates")).toBeInTheDocument();
  });

  it("expands product details accessibly", async () => {
    const user = userEvent.setup();
    render(<ProductExplorer products={[...products]} />);
    await user.click(screen.getByRole("button", { name: "Explore Camera Systems" }));
    expect(screen.getByText("Remote view")).toBeVisible();
  });
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `npm test -- app/_components/product-explorer.test.tsx`

Expected: FAIL because `ProductExplorer` does not exist.

- [ ] **Step 3: Implement filtering and disclosure**

Use button-based filters with `aria-pressed`, an `all` reset, keyed product cards, and disclosure buttons with `aria-expanded` and `aria-controls`. Keep both active filter and expanded product in component state; announce the visible result count through `aria-live="polite"`.

- [ ] **Step 4: Compose the products page and verify**

Add an intro explaining that Security Depot engineers integrated systems rather than selling anonymous boxes, render the explorer, and finish with `AssessmentCta`.

Run: `npm test -- app/_components/product-explorer.test.tsx && npm run build`

Expected: 2 tests pass and production build succeeds.

Commit: `feat: add interactive security product explorer`

### Task 6: Build the Guided Assessment Experience

**Files:**
- Create: `app/security_depot_web/app/contact/page.tsx`
- Create: `app/security_depot_web/app/_components/assessment-wizard.tsx`
- Create: `app/security_depot_web/app/_components/assessment-wizard.test.tsx`

**Interfaces:**
- Consumes: `AssessmentData`, `AssessmentErrors`, `EMPTY_ASSESSMENT`, `validateAssessmentStep`
- Produces: `AssessmentWizard`

- [ ] **Step 1: Write failing wizard tests**

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { AssessmentWizard } from "./assessment-wizard";

describe("AssessmentWizard", () => {
  it("blocks an incomplete first step", async () => {
    const user = userEvent.setup();
    render(<AssessmentWizard />);
    await user.click(screen.getByRole("button", { name: "Continue" }));
    expect(screen.getByText("Choose a property type.")).toBeVisible();
  });

  it("moves forward and back without losing the property type", async () => {
    const user = userEvent.setup();
    render(<AssessmentWizard />);
    await user.click(screen.getByRole("radio", { name: "Residential" }));
    await user.click(screen.getByRole("button", { name: "Continue" }));
    await user.click(screen.getByRole("button", { name: "Back" }));
    expect(screen.getByRole("radio", { name: "Residential" })).toBeChecked();
  });
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `npm test -- app/_components/assessment-wizard.test.tsx`

Expected: FAIL because `AssessmentWizard` does not exist.

- [ ] **Step 3: Implement the four-step wizard**

Use fieldsets and legends for Property, Concerns, Timeline, and Contact. Persist draft data under session-storage key `security-depot-assessment-draft`. Validate before advancing, focus the step heading after navigation, provide Back/Continue controls, and clear storage after confirmation. Submission must display: `Demo complete — your information was not transmitted. Call 403-250-5363 to request a live assessment.`

- [ ] **Step 4: Compose the contact route**

Place the wizard beside direct phone, address, weekday appointment note, and service-region information. Add unique metadata and an urgent-security note that directs emergencies to local emergency services rather than the form.

- [ ] **Step 5: Run tests and build**

Run: `npm test -- app/_components/assessment-wizard.test.tsx app/_lib/assessment.test.ts && npm run build`

Expected: 5 tests pass and the production build succeeds.

Commit: `feat: add guided security assessment flow`

### Task 7: Add Social Preview, Run Full Verification, and Publish

**Files:**
- Create: `app/security_depot_web/public/og.png`
- Modify: `app/security_depot_web/app/layout.tsx`
- Modify only if verification finds a defect: files under `app/security_depot_web/app/**`

**Interfaces:**
- Consumes: complete site
- Produces: verified production build and deployed Sites URL

- [ ] **Step 1: Create and inspect one bespoke social card**

Generate a 1200×630 landscape image using the finished graphite/cyan design, the headline `See every risk. Secure every layer.`, `Security Depot`, and a restrained surveillance-grid motif. Inspect the result; retry once only if text is wrong or illegible. Save the accepted asset as `public/og.png`.

- [ ] **Step 2: Wire social metadata**

Add Open Graph and X metadata for the title, description, and `/og.png`, resolving the absolute image URL from the incoming request host in the framework-supported metadata configuration.

- [ ] **Step 3: Run the complete automated verification**

Run: `npm test && npm run build`

Expected: all tests pass and the build exits with code 0.

- [ ] **Step 4: Check route and interaction requirements**

Confirm all six routes, current navigation states, mobile menu, phone links, product filters, product disclosures, assessment validation, Back behavior, demo-only confirmation, keyboard focus, and reduced-motion styling. Fix only observed defects and rerun `npm test && npm run build` after any change.

- [ ] **Step 5: Publish through Sites**

Deploy the verified build with the Sites hosting workflow. Open the deployed URL once and confirm the home route responds successfully.

- [ ] **Step 6: Commit final delivery changes**

Commit: `chore: finalize and verify Security Depot website`

