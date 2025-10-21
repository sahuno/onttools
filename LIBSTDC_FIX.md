# Docker Build Issue: libstdc++ Library Conflict

## Problem Description

The Docker build fails at step 22/24 (Dockerfile:223) with the following error:

```
apt-get: /usr/local/lib/libstdc++.so.6: version `GLIBCXX_3.4.32' not found (required by apt-get)
apt-get: /usr/local/lib/libstdc++.so.6: version `GLIBCXX_3.4.32' not found (required by /lib/x86_64-linux-gnu/libapt-private.so.0.0)
apt-get: /usr/local/lib/libstdc++.so.6: version `GLIBCXX_3.4.29' not found (required by /lib/x86_64-linux-gnu/libapt-private.so.0.0)
apt-get: /usr/local/lib/libstdc++.so.6: version `GLIBCXX_3.4.26' not found (required by /lib/x86_64-linux-gnu/libapt-private.so.0.0)
```

## Root Cause

At Dockerfile:172, the Dorado installation copies all bundled libraries to `/usr/local/lib/`:

```dockerfile
mv dorado-1.2.0-linux-x64/lib/* /usr/local/lib/
```

This includes Dorado's own `libstdc++.so.6` which has incompatible GLIBCXX versions. Since `/usr/local/lib/` takes precedence in the library search path, the system's `apt-get` command finds Dorado's incompatible library instead of the system library, causing the build to fail.

## Solution Options

### Option 1: Remove the cleanup step (Simplest)

**Implementation:**
Remove or comment out the cleanup command at Dockerfile:223-224:

```dockerfile
# Clean up
# RUN apt-get clean && \
#     rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
```

**Pros:**
- Simplest fix
- Docker handles layer cleanup automatically
- No impact on runtime functionality

**Cons:**
- Slightly larger final image size (negligible impact)

**Status:** ✅ IMPLEMENTED

---

### Option 2: Isolate Dorado libraries (Better isolation)

**Implementation:**
Move Dorado libraries to a dedicated directory and configure the linker:

```dockerfile
# Install dorado (latest version)
RUN wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-1.2.0-linux-x64.tar.gz && \
    tar -xzf dorado-1.2.0-linux-x64.tar.gz && \
    mv dorado-1.2.0-linux-x64/bin/* /usr/local/bin/ && \
    mkdir -p /opt/dorado/lib && \
    mv dorado-1.2.0-linux-x64/lib/* /opt/dorado/lib/ && \
    echo "/opt/dorado/lib" > /etc/ld.so.conf.d/dorado.conf && \
    ldconfig && \
    rm -rf dorado*
```

**Pros:**
- Better library isolation
- Prevents conflicts with system libraries
- Keeps the cleanup step functional
- More maintainable long-term

**Cons:**
- Requires testing to ensure Dorado still works correctly
- Slightly more complex configuration

---

### Option 3: Move cleanup earlier

**Implementation:**
Reorganize Dockerfile to run cleanup before Dorado installation:

```dockerfile
# Early cleanup (before Dorado)
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install dorado (latest version)
RUN wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-1.2.0-linux-x64.tar.gz && \
    tar -xzf dorado-1.2.0-linux-x64.tar.gz && \
    mv dorado-1.2.0-linux-x64/bin/* /usr/local/bin/ && \
    mv dorado-1.2.0-linux-x64/lib/* /usr/local/lib/ && \
    rm -rf dorado* && \
    ldconfig
```

**Pros:**
- Keeps cleanup functionality
- Minimal code changes

**Cons:**
- apt-get becomes unavailable after this point
- May break future Dockerfile modifications that need apt-get
- Not a proper solution to the underlying conflict

---

## Recommendation

- **Short-term:** Option 1 (already implemented) - gets the build working immediately
- **Long-term:** Consider Option 2 for better library management and maintainability

## Testing

After implementing any solution, verify:

```bash
./build_docker.sh
docker run --rm sahuno/onttools:latest dorado --version
docker run --rm sahuno/onttools:latest test_installation
```

## Date

2025-10-21
