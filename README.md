# ruby-vips

[![Gem Version](https://badge.fury.io/rb/ruby-vips.svg)](https://badge.fury.io/rb/ruby-vips)
[![Build Status](https://travis-ci.org/jcupitt/ruby-vips.svg?branch=master)](https://travis-ci.org/jcupitt/ruby-vips)

This gem provides a Ruby binding for the [libvips image processing
library](https://jcupitt.github.io/libvips).

Programs that use `ruby-vips` don't
manipulate images directly, instead they create pipelines of image processing
operations building on a source image. When the end of the pipe is connected
to a destination, the whole pipeline executes at once, streaming the image
in parallel from source to destination a section at a time. 

Because `ruby-vips` is parallel, it's quick, and because it doesn't need to
keep entire images in memory, it's light.  For example, the benchmark at
[vips-benchmarks](https://github.com/jcupitt/vips-benchmarks) loads a
large image, crops, shrinks, sharpens and saves again, and repeats 10 times.

```text
real time in seconds, fastest of three runs
benchmark       tiff    jpeg
ruby-vips.rb    0.66    0.44
image-magick    1.10    1.50
rmagick.rb      1.63    2.16

peak memory use in bytes
benchmark       peak RSS
ruby-vips.rb    58696
rmagick.rb      787564
```

See also [benchmarks at the official libvips
website](https://github.com/jcupitt/libvips/wiki/Speed-and-memory-use).
There's a handy blog post explaining [how libvips opens
files](http://libvips.blogspot.co.uk/2012/06/how-libvips-opens-file.html)
which gives some more background.

## Requirements

  * macOS, Linux, and Windows tested

  * libvips 8.2 or later, see the [libvips install instructions](https://jcupitt.github.io/libvips/install.html)

  * [ruby-ffi](https://github.com/ffi/ffi) 1.9 or later 

  * Ruby 2.0+, JRuby should work

## Install

It's just:

```
	$ gem install ruby-vips
```

or include it in `Gemfile`:

```ruby
gem 'ruby-vips'
```

On Windows, you'll need to set the `RUBY_DLL_PATH` environment variable to 
point to the libvips bin directory.

Take a look in `examples/`. There is full yard documentation, take a look
there too.

# Example

```ruby
require 'vips'

im = Vips::Image.new_from_file filename

# put im at position (100, 100) in a 3000 x 3000 pixel image, 
# make the other pixels in the image by mirroring im up / down / 
# left / right, see
# https://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-embed
im = im.embed 100, 100, 3000, 3000, extend: :mirror

# multiply the green (middle) band by 2, leave the other two alone
im *= [1, 2, 1]

# make an image from an array constant, convolve with it
mask = Vips::Image.new_from_array [
    [-1, -1, -1],
    [-1, 16, -1],
    [-1, -1, -1]], 8
im = im.conv mask, precision: :integer

# finally, write the result back to a file on disk
im.write_to_file output_filename
```

# Older versions

There are two older versions of this gem.

The `0.3-stable` branch is written in C and supports a different API. It still
works, but is only maintained for compatibility.

The `1.0-stable` branch is based on `gobject-introspection` rather than
`ffi`. It supports the same API as the current version, but is harder to
install, less portable, slower, and less stable.
