# Rbuf Viewer

LiveView-based editor for Ark rbuf payloads.

## Notes

- Generic payloads are loaded by reading the embedded schema name and embedded
  registry from the binary trailer, then decoding the object in memory.
- Typed payloads rely on a separately loaded `.ir` registry and explicit schema
  selection.
- Complex values start collapsed by default. Primitive values remain inline.
- Collections are edited in memory and then serialized back to binary on save.
- Byte buffers are collapsed by default and only expanded when the user opens
  them.

## Run

From `apps/rbuf_viewer`:

```bash
mix deps.get
cd assets && npm install
mix phx.server
```
