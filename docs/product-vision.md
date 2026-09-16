# Product vision

## Problem

People store files across NAS devices, cloud drives, WebDAV servers and object storage. Mobile apps usually require separate clients, duplicate downloads, or support only the operating system's document picker. Legacy apps may only accept a local filesystem or removable-storage path.

The original validation case is BOOK☆WALKER on Android: let a user select storage backed by NAS or cloud without keeping the entire library on the phone. This is a demanding compatibility test, not the boundary of the product.

## Vision

SUIZAI makes remote storage feel local while keeping the user's data path direct and understandable.

```text
Cloud accounts + NAS + object storage
                  ↓
          SUIZAI storage core
                  ↓
      System file integration + cache
                  ↓
              Mobile apps
```

## Principles

1. **Local first:** credentials, metadata and cache live on the device.
2. **Direct connection:** file content does not pass through a SUIZAI-operated relay by default.
3. **Progressive compatibility:** standard platform APIs first; privileged Android integration only as an explicit mode.
4. **Provider neutrality:** the core depends on a capability contract, not a specific cloud vendor or OpenList.
5. **Truthful storage:** pending uploads, conflicts, offline state and cache residency must be visible.
6. **Recoverability:** a cache failure must not silently imply a successful remote write.

## Target users

- NAS owners who need reliable mobile access outside their home network.
- Users with files split across multiple cloud accounts.
- Readers and media users with libraries larger than phone storage.
- Privacy-conscious users who prefer direct connections.
- Technical users who use S3, SFTP, WebDAV or self-hosted services.

## Non-goals for v1

- Operating a new cloud storage service.
- Collaboration suites, online document editing or team administration.
- Transparent virtual SD support on stock iOS.
- Claiming compatibility with every Android app before device testing.
- Depending on a hosted OpenList server.

## Positioning

> SUIZAI is not another cloud file browser. It is the mobile layer that makes every storage location usable where your apps expect files.

Primary tagline: **Every file, ready anywhere.**

Traditional Chinese: **你的檔案，隨在隨載。**
