# Agentforce - Gemini 2.0 Internet Search POC

A proof of concept Agentforce action that calls Google Gemini with optional Google Search grounding and formats the response for Agentforce.

This repository contains the Salesforce DX source retrieved from the `Agentforce - Gemini 2.0 Internet Search POC` unmanaged 1GP package hosted in the `pamigration` org. It is intended to be deployable as source-controlled metadata and to serve as implementation documentation for the solution.

## Solution Highlights
- The Flow passes an API key, prompt, model, and generation settings into Apex.
- Includes a Remote Site Setting for the Gemini API endpoint.

## Architecture
Typical execution path:

1. An Agentforce action or topic receives a user request.
2. The action invokes a Flow, Prompt Builder template, or Apex invocable target.
3. Supporting Apex, Prompt Builder templates, and Salesforce metadata perform the callout, extraction, generation, formatting, or record update.
4. The result is returned to Agentforce or stored in Salesforce records for follow-up work.

## Metadata Inventory
- GenAiFunctions: `Gemini_2_0_API_Call_Agent_Action`
- Prompt templates: `Gemini_2_0_Answer_Formatter`
- Flows: `Gemini_2_0_API_Call_Flow`
- Apex classes: `Gemini_API_Call`
- Integration metadata: 1 credential/remote-site component(s)

## Agentforce Actions and Topics
- `Gemini_2_0_API_Call_Agent_Action` -> `Gemini_2_0_API_Call_Flow` (flow) - This flow makes an API call to Gemini 2.0 to assist with live web research.

## Flows
- `Gemini_2_0_API_Call_Flow` (Gemini 2.0 API Call Flow) status `Active` type `AutoLaunchedFlow` - This flow makes an API call to Gemini 2.0 to assist with live web research. Key actions: Gemini API Call (apex: Gemini_API_Call), Rich Text Formatting (generatePromptResponse: Gemini_2_0_Answer_Formatter).

## Prompt Templates
- `Gemini_2_0_Answer_Formatter` - This prompt templates formats for Rich Text output for use in Agentforce. (1 version(s); statuses: Published; inputs: `Gemini_Response`, `search_query`, `Gemini_Metadata`)

## Apex
Apex runtime classes: `Gemini_API_Call`

Apex test classes: None

Invocable methods and key callouts:
- Gemini_API_Call: Call Gemini API - Calls the Gemini API with a user-defined API key, prompt, model, and configurable generation parameters. Optionally include Google Search grounding.
- Observed endpoints: `https://generativelanguage.googleapis.com/v1beta/models/`

## Data Model and UI
- None retrieved.

## Integrations and Credentials
- Remote Site Setting `Gemini_API` -> `https://generativelanguage.googleapis.com`
- Apex endpoints/callouts observed: `https://generativelanguage.googleapis.com/v1beta/models/`

No credential secret values were included in the retrieved metadata. Any API keys or named-principal secrets must be configured in the target org after deployment.
- The retrieved package contained a hardcoded Gemini flow variable value; this repo replaces it with `REPLACE_WITH_GEMINI_API_KEY` before publishing.

## Prerequisites
- Salesforce org with Metadata API support and Salesforce CLI access.
- Agentforce and Prompt Builder features enabled for metadata that uses GenAiFunction, GenAiPlugin, or GenAiPromptTemplate.
- Permission to deploy Apex, Flow, Prompt Builder, Named Credential, External Credential, and custom object metadata as applicable.
- Access to any external API provider used by this package.

## Deployment
Authenticate to the target org, then validate first:

```bash
sf org login web --alias <target-org>
sf project deploy start --dry-run --manifest manifest/package.xml --target-org <target-org> --wait 30
```

Deploy after the dry run succeeds:

```bash
sf project deploy start --manifest manifest/package.xml --target-org <target-org> --wait 30
```

## Post-Deploy Setup
- Provide a Google Gemini API key to the Flow or agent action input.
- Verify the Gemini_API remote site setting is active.
- Review whether the API key should be moved to Named Credential / External Credential before production use.

## Testing and Validation
- Run a metadata dry run before deploying to a shared org.
- Run Apex tests listed above when present.
- Open each Flow in Flow Builder and confirm it is active or activate it after reviewing org-specific references.
- Open Prompt Builder templates and confirm the expected published version, model, and inputs.
- Test the Agentforce action with a low-risk sample prompt before giving it to end users.

## Package Provenance
- Source package: `Agentforce - Gemini 2.0 Internet Search POC`
- MetadataPackageId: `033Hn000000hMXnIAM`
- Retrieved from org alias: `pamigration`
- Package versions observed: `1.0.0 Beta (Beta Release)`, `1.1.0 Beta (Beta Release)`
- Repository name: `agentforce-gemini-2-0-internet-search-poc`

## Notes for Maintainers
- Keep generated secrets, local org auth files, `.sf`, `.sfdx`, and deployment output out of source control.
- Treat prompt templates and Agentforce action descriptions as production behavior, not just documentation.
- For production hardening, prefer Named Credential and External Credential patterns over passing API keys directly through Flow variables.
