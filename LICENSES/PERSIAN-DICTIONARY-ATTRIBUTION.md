# Persian dictionary attribution

`fa_wordlist.combined.gz` combines and transforms these pinned sources:

- Persian frequency data from
  [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
  commit `525f9b560de45753a5ea01069454e72e9aa541c6`.
- The Lilak Persian spell-checking dictionary, copyright 2015 Mostafa
  Sedaghat Joo, as normalized by
  [wooorm/dictionaries](https://github.com/wooorm/dictionaries) commit
  `8cfea406b505e4d7df52d5a19bce525df98c54ab`.

The frequency data repository is distributed under the MIT License:

> Copyright (c) 2016 Hermit Dave
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

The Lilak dictionary and affix data are licensed under the Apache License,
Version 2.0. A complete copy of that license is already included in this
package as `NOTO-EMOJI-SVG-LICENSE.txt`.

The generated FUTO Keyboard index is an offline prediction data derivative of
those sources. The exact transformation, input hashes, output hashes, and
reproduction command are documented in `dictionaries/README.md`.
