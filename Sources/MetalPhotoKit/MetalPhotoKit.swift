// MetalPhotoKit
//
// GPU-accelerated photo processing built on Metal.
//
// The render pipeline core:
// - `MetalContext` wraps the GPU device and its command queue.
// - `TextureLoader` moves pixels between CPU images and GPU textures.
// - `Filter` and `FilterChain` compose GPU effects into a single batch of work.
