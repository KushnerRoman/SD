# Security Depot Website Redesign

## Objective

Redesign Security Depot's website as a modern, high-trust, multi-page experience that presents the company as Calgary's advanced security and surveillance specialist. The primary conversion goal is to have qualified visitors request a security assessment.

## Audience

- Homeowners seeking monitored security, surveillance, and automation
- Commercial operators needing surveillance, access control, gates, and secure storage
- Condominium boards and property managers planning access, intercom, parking, and common-area security

## Brand Direction

The visual direction is **Security Operations**: a refined command-center aesthetic that feels advanced, calm, capable, and credible.

- Near-black graphite and steel-grey foundations
- Electric cyan as the primary signal color
- Restrained green for healthy system states
- Large editorial display type paired with compact technical labels
- Grid lines, timestamps, status indicators, targeting brackets, and controlled glow
- Real security-system language rather than generic hacker imagery

Motion will be purposeful and restrained. Scanning lines, status changes, scroll reveals, subtle depth, and cursor-responsive lighting will support the surveillance theme. Reduced-motion preferences will disable nonessential animation.

## Information Architecture

### Home

A cinematic introduction to the company and its capabilities, including a surveillance-style hero, trust indicators, solution categories, a live-system visualization, the engagement process, service-area coverage, and repeated assessment calls to action.

### Residential

Content focused on intrusion detection, cameras, remote monitoring, automation, and family-oriented security scenarios. The page should explain how components work together as a complete system.

### Commercial

Content focused on video surveillance, access control, foldaway gates, roll shutters, secure equipment storage, automation, and scalable multi-site protection.

### Condominiums

Content focused on lobby and intercom systems, resident credentials, parking and common-area surveillance, property-manager workflows, and retrofit planning.

### Products

A capability-led product catalog, not an e-commerce store. Visitors can filter product families and expand cards for relevant features and use cases. Product families include alarms, video surveillance and recording, intercom and access control, gates and shutters, automation, security film, and secure storage.

### Contact

A guided assessment experience supported by direct phone and location details. The form asks for property type, security concerns, timeline, contact details, and preferred contact method.

## Conversion Journey

Every page includes a persistent, prominent **Request Assessment** action. Supporting calls to action appear after meaningful content sections. Direct phone access remains visible for urgent or high-intent visitors.

The assessment form uses a short multi-step flow with clear progress, inline validation, and a polished confirmation state. Until a real backend or CRM is connected, the interface must explicitly describe the request as a demo/local submission and must not imply that Security Depot received it.

## Shared Components

- Responsive global navigation with current-page state
- Persistent assessment call to action
- Footer with business details, service regions, and solution links
- Solution and capability cards
- Trust and system-status indicators
- Surveillance viewport and telemetry motifs
- Section headers and conversion bands
- Multi-step assessment form

Each shared component will expose a focused interface and remain independent of route-specific content.

## Content Strategy

The redesign will use Security Depot's public business facts as source material: more than 40 years of experience, Calgary-area service, residential/commercial/condominium coverage, product and service categories, telephone number, address, and listed regional coverage. Copy will be rewritten for clarity and modern positioning without inventing certifications, customer counts, response-time guarantees, pricing, monitoring claims, or product partnerships.

## Interaction Design

- Hero surveillance panel cycles through a small set of camera zones and system states
- Product filters update visible families without navigation
- Expandable product details work by mouse, touch, and keyboard
- Scroll-based reveals are subtle and do not block content
- Navigation and page transitions preserve orientation
- Form state persists while moving between its steps during the current browser session
- Focus styles, accessible labels, semantic landmarks, and strong contrast are required

## Responsive Behavior

Desktop layouts use asymmetric editorial grids and command-center panels. Tablet layouts simplify secondary telemetry while preserving hierarchy. Mobile layouts become a single-column experience with touch-friendly controls, compact status modules, and an always-accessible assessment action that does not obscure content.

## Technical Approach

Use a React-based multi-route site with shared layout and reusable components. Route content and product data remain separate from presentation logic. Motion utilities honor `prefers-reduced-motion`. The assessment submission adapter is isolated so a future email, CRM, or booking integration can replace the local demonstration behavior without rewriting the form.

No authentication, payment, e-commerce checkout, persistent database, or external CRM integration is part of this version.

## Failure and Empty States

- Form errors appear beside the relevant field and are announced accessibly
- Product filters always offer a clear reset path
- Interactive visualizations degrade to static, fully readable content if scripting or animation is unavailable
- Missing optional visual media never removes essential copy or actions
- Local form confirmation accurately states that no live request was transmitted

## Verification

- All six routes render and link correctly
- Desktop, tablet, and mobile layouts remain usable
- Product filtering and expandable details work with keyboard, pointer, and touch
- Form steps, validation, back navigation, and confirmation behavior work correctly
- Semantic structure, focus order, contrast, labels, and reduced-motion behavior are checked
- Production build succeeds without route or type errors
- Internal links and primary calls to action resolve correctly

## Success Criteria

The finished site should make Security Depot feel established and technologically current, clearly distinguish its three customer segments, explain the breadth of its integrated solutions, and make requesting an assessment the obvious next step from every route.
