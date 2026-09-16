# Market and competitive analysis

Research snapshot: September 2026. Verify pricing and feature details again before launch.

## Competitive groups

| Product | Platforms | Strength | Gap SUIZAI can target |
|---|---|---|---|
| OpenList Mobile | Android; experimental iOS | Broad OpenList driver ecosystem; mobile server | Server-oriented; native system storage integration is not the central promise |
| Owlfiles | Android, iOS, desktop | Mature NAS/cloud browser and media features | Differentiate through files-on-demand semantics and legacy-app compatibility |
| FE File Explorer | Android, iOS, macOS | Broad protocols, transfer, streaming and sync | Same as above; avoid competing only on provider count |
| Driio | iOS, iPadOS, macOS | Native Files/Finder integration for remote protocols | Strong reference competitor for Apple File Provider experience |
| FileBrowser | Apple platforms | Mature file access and enterprise configuration | SUIZAI should lead with cross-platform virtualization rather than file browsing |
| Round Sync | Android | Open-source rclone ecosystem and scheduled sync | Opportunity in polished system integration, cache truthfulness and iOS parity |
| FolderSync | Android | Mature two-way folder synchronization | SUIZAI is on-demand access first, not scheduled folder mirroring |
| CloudMounter / Mountain Duck | Desktop | Remote storage as desktop drives | Validate demand for mount semantics; mobile restrictions create a different product |

## Key conclusion

The general-purpose mobile file-manager category is crowded. Provider count alone is not a durable advantage. SUIZAI should compete on:

1. Remote storage exposed to other apps through native platform surfaces.
2. Predictable files-on-demand and bounded cache behavior.
3. Transparent write-back, conflict and recovery states.
4. Android compatibility for legacy apps that do not support SAF.
5. One shared cross-platform storage engine with native platform integrations.
6. Privacy-first direct connections with no mandatory SUIZAI server.

## Notable market change

OpenList Mobile now exists, so “OpenList on a phone” is no longer a sufficiently distinct product claim. OpenList should be an optional v2 provider. The product moat must be native integration and storage virtualization.

## Public references

- OpenList Mobile: https://doc.oplist.org/ecosystem/official_mobile
- Owlfiles: https://www.skyjos.com/owlfiles/
- FE File Explorer: https://www.skyjos.com/fileexplorer/
- Driio: https://apps.apple.com/us/app/driio/id6757922119
- FileBrowser: https://www.stratospherix.com/products/filebrowserprofessional/
- Round Sync: https://github.com/newhinton/Round-Sync
- FolderSync: https://play.google.com/store/apps/details?id=dk.tacit.android.foldersync.lite
- Android Storage Access Framework: https://developer.android.com/guide/topics/providers/document-provider
- Apple File Provider: https://developer.apple.com/documentation/fileprovider

## Validation questions

- Which Android storage API does BOOK☆WALKER actually enumerate?
- Will users trust write-back caching for important files?
- Which first two providers cover the highest-value early adopters?
- Is a paid power-user utility viable without operating a relay service?
- Does “legacy app compatibility” justify a separate sideload/root edition?
