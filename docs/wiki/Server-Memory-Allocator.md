# Server Memory Allocator

How the dedicated server and headless clients select a memory allocator through the Arma 2 OA `-malloc` launch parameter, the gotcha that silently drops a process to the default Windows heap, and how to verify which allocator a running process actually loaded.

## How `-malloc` Loads An Allocator

Arma 2 OA 1.64 (build `1.64.144629`) resolves `-malloc=<name>` to `<game>\Dll\<name>.dll` and `LoadLibrary`s it during engine init. The DLL must export the Bohemia allocator interface (`_MemAlloc@4`, `_MemFree@4`, `_MemSize@4`, `_MemFlushCache@4`, `_MemFlushCacheAll@0`, `_MemTotalCommitted@0`, `_MemTotalReserved@0`); the engine binds those exports and routes its allocations through them.

If the named DLL is missing from `Dll\` or fails to load, the engine silently falls back to the default Windows heap. There is no RPT line for this on `1.64.144629` (the `Allocator:` / `falling back` strings exist in the binary but are not emitted at runtime), so the `-malloc` flag stays in the command line and a config that looks tuned can actually be running on the default heap.

Two facts that are easy to get wrong:

- The engine loads the explicitly-named DLL regardless of its internal allocator name table. That table (`tbb4malloc_bi`, `tbb3malloc_bi`, `jemalloc_bi`, `tcmalloc_bi`, `nedmalloc_bi`, `custommalloc_bi`, `system`) is the auto-detection order used when no `-malloc` is supplied; it does not gate explicit `-malloc=<name>` loading. A DLL whose base name is not in that table still loads if it exports the interface (e.g. `mimalloc`).
- Stock allocator DLLs ship under `Expansion\beta\dll\` as well as the main `Dll\` folder. If a stock DLL is removed from `Dll\`, any process whose `-malloc` names it drops to the default heap even though its launch flag is unchanged.

## Reference Configuration

| Process | Launch flag | DLL required in `Dll\` | Loaded allocator |
| --- | --- | --- | --- |
| Dedicated server | `-malloc=mimalloc` | `mimalloc.dll` | mimalloc |
| Headless client 1/2 | `-malloc=tbb4malloc_bi` | `tbb4malloc_bi.dll` | tbb4malloc_bi |

The server and both headless clients run on a custom allocator, not the default heap. The expected gain on a dedicated server is modest: Bohemia notes the dedicated-server allocator benefit is small because of low concurrency, so the practical win is heap-fragmentation stability across long sessions rather than raw FPS. Mixing allocators across processes is fine; each process loads its own independently.

## Verifying Which Allocator A Process Loaded

This is the part that misleads people, because the obvious checks give false results on a 32-bit Arma process.

Do not trust these:

- `tasklist /m <dll>`, `Get-Process .Modules`, and WMI `CIM_ProcessExecutable` are WOW64-blind: a 64-bit tool enumerating a 32-bit process misses its modules, so they report "not loaded" even when the allocator is loaded.
- The "open the DLL for exclusive read and see if it throws" file-lock test is invalid for DLLs. A `LoadLibrary`'d DLL maps as an image section with no conflicting file handle, so an exclusive read open succeeds even while the DLL is loaded. That test only works on the primary `.exe`, which holds a real file handle.
- The RPT emits no allocator line on this build, so its absence proves nothing.

Use one of these instead:

- Module enumeration via `EnumProcessModulesEx` with `LIST_MODULES_ALL` (`0x03`), the documented WOW64-correct way to list a 32-bit process's modules from 64-bit code. If `...\Dll\<name>.dll` appears in the list, it is loaded.
- Sysinternals `listdlls <process>`, which produces the same module list without writing code.
- The delete or rename test: a mapped image cannot be deleted ("file in use"). If the DLL deletes cleanly while the process is running, it is not loaded. This is the quickest one-off check and is the canonical signal that a custom allocator is active.

## Launch Parameters

Dedicated server (Windows service `Arma2OA-PR8` via nssm; stored in `AppParameters`):

```text
arma2oaserver.exe -port=2302 -config=...\profiles-pr8\server-pr8.cfg -cfg=...\profiles-pr8\basic.cfg "-mod=...\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf" -malloc=mimalloc -world=empty
```

Headless clients (`hc_launch.cmd` / `hc2_launch.cmd`):

```text
ArmA2OA.exe -client -connect=127.0.0.1 -port=2302 -window -cfg=...\hc-profile\hc-video.cfg "-mod=...\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf" -name=HC -exThreads=3 -cpuCount=2 -malloc=tbb4malloc_bi -maxMem=2047 -world=empty -nosplash -noPause -noSound
```

Large pages: Arma 2 OA has no `-hugepages` parameter (that is an Arma 3 flag). Any large-page support would run through the allocator DLL's own privilege handling and `VirtualAlloc` path and is not currently enabled on the server.

## Continue Reading

Server FPS: [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) · HC sizing: [Headless client scaling and topology](Headless-Client-Scaling-And-Topology) · Perf patches: [Performance opportunity sweep](Performance-Opportunity-Sweep) · AI/HC runtime: [AI, headless and performance](AI-Headless-And-Performance)
