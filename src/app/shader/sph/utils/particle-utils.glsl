
ivec2 ndx2tex(ivec2 dimensions, int index) {
    int y = index / dimensions.x;
    int x = index % dimensions.x;
    return ivec2(x, y);
}

int tex2ndx(ivec2 dimensions, ivec2 tex) {
    return tex.x + tex.y * dimensions.x;
}

ivec2 pos2CellIndex(vec2 p, ivec2 cellTexSize, vec2 domainScale, float cellSize) {
    vec2 pi = p * 0.5 + 0.5;
    pi = clamp(pi, vec2(0.001), vec2(.999));
    pi *= domainScale;
    return ivec2(pi / cellSize);
}

int pos2CellId(vec2 p, ivec2 cellTexSize, vec2 domainScale, float cellSize) {
    ivec2 cellIndex = pos2CellIndex(p, cellTexSize, domainScale, cellSize);
    return tex2ndx(cellTexSize, cellIndex);
}

int getFlatCellIndex(ivec2 cellIndex, int numGridCells) {
    int p1 = 73856093; // some large primes
    int p2 = 19349663;
    int n = p1 * cellIndex.x ^ p2 * cellIndex.y;
    n %= numGridCells;
    return n;
}