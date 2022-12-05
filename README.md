# Liquid-Geo

![Liquid-Geo Screenshot](https://github.com/robert-leitl/liquid-geo/blob/main/cover.jpg?raw=true)

This web experiment is inspired by the liquid-geo interface designs form the movie [Man of Steel](https://en.wikipedia.org/wiki/Man_of_Steel_(film)). It allows the user to record a short audio snippet. This snippet can then be played back in a distorted version and the sphere responds to the audio signal. In addition, the beads on the surface of the sphere can be manipulated by touch or mouse movement.

[DEMO](https://robert-leitl.github.io/liquid-geo/dist/?debug=true)

### Features
- SPH fluid simulation on sphere surface [Github Repo](https://robert-leitl.github.io/gpgpu-2d-sph-fluid-simulation)
- Screen-space halo and bloom effect inspired by this [article](https://john-chapman.github.io/2017/11/05/pseudo-lens-flare.html) from John Chapman.
- Audio recording and distorted playback using web audio API and tone.js.