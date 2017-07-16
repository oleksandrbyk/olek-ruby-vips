# This module provides a set of overrides for the [vips image processing 
# library](https://jcupitt.github.io/libvips/)
# used via the [gobject-introspection
# gem](https://rubygems.org/gems/gobject-introspection). 
#
# It needs vips-8.2 or later to be installed, 
# and `Vips-8.0.typelib`, the vips typelib, needs to be on your 
# `GI_TYPELIB_PATH`.
#
# # Example
#
# ```ruby
# require 'vips'
#
# if ARGV.length < 2
#     raise "usage: #{$PROGRAM_NAME}: input-file output-file"
# end
#
# im = Vips::Image.new_from_file ARGV[0], :access => :sequential
#
# im *= [1, 2, 1]
#
# mask = Vips::Image.new_from_array [
#         [-1, -1, -1],
#         [-1, 16, -1],
#         [-1, -1, -1]], 8
# im = im.conv mask
#
# im.write_to_file ARGV[1]
# ```
#
# This example loads a file, boosts the green channel (I'm not sure why), 
# sharpens the image, and saves it back to disc again. 
#
# Reading this example line by line, we have:
#
# ```ruby
# im = Vips::Image.new_from_file ARGV[0], :access => :sequential
# ```
#
# {Image.new_from_file} can load any image file supported by vips. In this
# example, we will be accessing pixels top-to-bottom as we sweep through the
# image reading and writing, so `:sequential` access mode is best for us. The
# default mode is `:random`, this allows for full random access to image pixels,
# but is slower and needs more memory. See {Access}
# for full details
# on the various modes available. You can also load formatted images from 
# memory buffers, create images that wrap C-style memory arrays, or make images
# from constants.
#
# The next line:
#
# ```ruby
# im *= [1, 2, 1]
# ```
#
# Multiplying the image by an array constant uses one array element for each
# image band. This line assumes that the input image has three bands and will
# double the middle band. For RGB images, that's doubling green.
#
# Next we have:
#
# ```ruby
# mask = Vips::Image.new_from_array [
#         [-1, -1, -1],
#         [-1, 16, -1],
#         [-1, -1, -1]], 8
# im = im.conv mask
# ```
#
# {Image.new_from_array} creates an image from an array constant. The 8 at
# the end sets the scale: the amount to divide the image by after 
# integer convolution. See the libvips API docs for `vips_conv()` (the operation
# invoked by {Image#conv}) for details on the convolution operator. 
#
# Finally:
#
# ```ruby
# im.write_to_file ARGV[1]
# ```
#
# {Image#write_to_file} writes an image back to the filesystem. It can 
# write any format supported by vips: the file type is set from the filename 
# suffix. You can also write formatted images to memory buffers, or dump 
# image data to a raw memory array. 
#
# # How it works
#
# The C sources to libvips include a set of specially formatted
# comments which describe its interfaces. When you compile the library,
# gobject-introspection generates `Vips-8.0.typelib`, a file 
# describing how to use libvips.
#
# The `gobject-introspection` gem loads this typelib and uses it to let you 
# call 
# functions in libvips directly from Ruby. However, the interface you get 
# from raw gobject-introspection is rather ugly, so the `ruby-vips` gem 
# adds a set 
# of overrides which try to make it nicer to use. 
#
# The API you end up with is a Ruby-ish version of the [VIPS C 
# API](https://jcupitt.github.io/libvips/API/current). 
# Full documentation
# on the operations and what they do is there, you can use it directly. This
# document explains the extra features of the Ruby API and lists the available 
# operations very briefly. 
#
# # Automatic wrapping
#
# `ruby-vips` adds a {Image.method_missing} handler to {Image} and uses
# it to look up vips operations. For example, the libvips operation `add`, which
# appears in C as `vips_add()`, appears in Ruby as {Image#add}. 
#
# The operation's list of required arguments is searched and the first input 
# image is set to the value of `self`. Operations which do not take an input 
# image, such as {Image.black}, appear as class methods. The remainder of
# the arguments you supply in the function call are used to set the other
# required input arguments. If the final supplied argument is a hash, it is used
# to set any optional input arguments. The result is the required output 
# argument if there is only one result, or an array of values if the operation
# produces several results. If the operation has optional output objects, they
# are returned as a final hash.
#
# For example, {Image#min}, the vips operation that searches an image for 
# the minimum value, has a large number of optional arguments. You can use it to
# find the minimum value like this:
#
# ```ruby
# min_value = image.min
# ```
#
# You can ask it to return the position of the minimum with `:x` and `:y`.
#   
# ```ruby
# min_value, opts = min :x => true, :y => true
# x_pos = opts['x']
# y_pos = opts['y']
# ```
#
# Now `x_pos` and `y_pos` will have the coordinates of the minimum value. 
# There's actually a convenience function for this, {Image#minpos}.
#
# You can also ask for the top *n* minimum, for example:
#
# ```ruby
# min_value, opts = min :size => 10, :x_array => true, :y_array => true
# x_pos = opts['x_array']
# y_pos = opts['y_array']
# ```
#
# Now `x_pos` and `y_pos` will be 10-element arrays. 
#
# Because operations are member functions and return the result image, you can
# chain them. For example, you can write:
#
# ```ruby
# result_image = image.real.cos
# ```
#
# to calculate the cosine of the real part of a complex image. 
# There are also a full set
# of arithmetic operator overloads, see below.
#
# libvips types are also automatically wrapped. The override looks at the type 
# of argument required by the operation and converts the value you supply, 
# when it can. For example, {Image#linear} takes a `VipsArrayDouble` as 
# an argument 
# for the set of constants to use for multiplication. You can supply this 
# value as an integer, a float, or some kind of compound object and it 
# will be converted for you. You can write:
#
# ```ruby
# result_image = image.linear 1, 3 
# result_image = image.linear 12.4, 13.9 
# result_image = image.linear [1, 2, 3], [4, 5, 6] 
# result_image = image.linear 1, [4, 5, 6] 
# ```
#
# And so on. A set of overloads are defined for {Image#linear}, see below.
#
# It does a couple of more ambitious conversions. It will automatically convert
# to and from the various vips types, like `VipsBlob` and `VipsArrayImage`. For
# example, you can read the ICC profile out of an image like this: 
#
# ```ruby
# profile = im.get_value "icc-profile-data"
# ```
#
# and profile will be a byte array.
#
# If an operation takes several input images, you can use a constant for all but
# one of them and the wrapper will expand the constant to an image for you. For
# example, {Image#ifthenelse} uses a condition image to pick pixels 
# between a then and an else image:
#
# ```ruby
# result_image = condition_image.ifthenelse then_image, else_image
# ```
#
# You can use a constant instead of either the then or the else parts and it
# will be expanded to an image for you. If you use a constant for both then and
# else, it will be expanded to match the condition image. For example:
#
# ```ruby
# result_image = condition_image.ifthenelse [0, 255, 0], [255, 0, 0]
# ```
#
# Will make an image where true pixels are green and false pixels are red.
#
# This is useful for {Image#bandjoin}, the thing to join two or more 
# images up bandwise. You can write:
#
# ```ruby
# rgba = rgb.bandjoin 255
# ```
#
# to append a constant 255 band to an image, perhaps to add an alpha channel. Of
# course you can also write:
#
# ```ruby
# result_image = image1.bandjoin image2
# result_image = image1.bandjoin [image2, image3]
# result_image = Vips::Image.bandjoin [image1, image2, image3]
# result_image = image1.bandjoin [image2, 255]
# ```
#
# and so on. 
# 
# # Automatic YARD documentation
#
# The bulk of these API docs are generated automatically by 
# {Vips::generate_yard}. It examines
# libvips and writes a summary of each operation and the arguments and options
# that that operation expects. 
# 
# Use the [C API 
# docs](https://jcupitt.github.io/libvips/API/current) 
# for more detail.
#
# # Exceptions
#
# The wrapper spots errors from vips operations and raises the {Vips::Error}
# exception. You can catch it in the usual way. 
#
# # Enums
#
# The libvips enums, such as `VipsBandFormat` appear in ruby-vips as classes
# like {Vips::BandFormat}. Overloads let you manipulate them in the obvious 
# way. For example:
#
# ```ruby
# irb(main):002:0> im = Vips::Image.new_from_file "IMG_1867.JPG"
# => #<Vips::Image:0x13e9760 ptr=0x1a88010>
# irb(main):003:0> im.format
# => #<Vips::BandFormat uchar>
# irb(main):004:0> im.format == :uchar
# => true
# irb(main):005:0> im.format == "uchar"
# => true
# irb(main):007:0> im.format == 0
# => true
# ```
#
# The `0` is the C value of the enum. 
# 
# # Draw operations
#
# Paint operations like {Image#draw_circle} and {Image#draw_line}
# modify their input image. This
# makes them hard to use with the rest of libvips: you need to be very careful
# about the order in which operations execute or you can get nasty crashes.
#
# The wrapper spots operations of this type and makes a private copy of the
# image in memory before calling the operation. This stops crashes, but it does
# make it inefficient. If you draw 100 lines on an image, for example, you'll
# copy the image 100 times. The wrapper does make sure that memory is recycled
# where possible, so you won't have 100 copies in memory. 
#
# If you want to avoid the copies, you'll need to call drawing operations
# yourself.
#
# # Overloads
#
# The wrapper defines the usual set of arithmetic, boolean and relational
# overloads on image. You can mix images, constants and lists of constants
# (almost) freely. For example, you can write:
#
# ```ruby
# result_image = ((image * [1, 2, 3]).abs < 128) | 4
# ```
#
# # Expansions
#
# Some vips operators take an enum to select an action, for example 
# {Image#math} can be used to calculate sine of every pixel like this:
#
# ```ruby
# result_image = image.math :sin
# ```
#
# This is annoying, so the wrapper expands all these enums into separate members
# named after the enum. So you can write:
#
# ```ruby
# result_image = image.sin
# ```
#
# # Convenience functions
#
# The wrapper defines a few extra useful utility functions: 
# {Image#get_value}, {Image#set_value}, {Image#bandsplit}, 
# {Image#maxpos}, {Image#minpos}, 
# {Image#median}.

require 'ffi'

module Vips
    private

    attach_function :vips_image_new_matrix_from_array, 
        [:int, :int, :pointer, :int], :pointer

    attach_function :vips_image_copy_memory, [:pointer], :pointer

    attach_function :vips_filename_get_filename, [:string], :string
    attach_function :vips_filename_get_options, [:string], :string
    attach_function :vips_filename_get_options, [:string], :string

    attach_function :vips_foreign_find_load, [:string], :string
    attach_function :vips_foreign_find_save, [:string], :string
    attach_function :vips_foreign_find_load_buffer, [:pointer, :size_t], :string
    attach_function :vips_foreign_find_save_buffer, [:string], :string

    attach_function :vips_image_get_typeof, [:pointer, :string], :GType
    attach_function :vips_image_get, [:pointer, :string, GLib::GValue.ptr], :int
    attach_function :vips_image_set, [:pointer, :string, GLib::GValue.ptr], :void
    attach_function :vips_image_remove, [:pointer, :string], :void

    attach_function :vips_band_format_iscomplex, [:int], :int
    attach_function :vips_band_format_isfloat, [:int], :int

    attach_function :nickname_find, :vips_nickname_find, [:GType], :string

    public

    # This class represents a libvips image. See the {Vips} module documentation
    # for an introduction to using this module.

    class Image < Vips::Object
        private

        # the layout of the VipsImage struct
        module ImageLayout
            def self.included(base)
                base.class_eval do
                    layout :parent, Vips::Object::Struct
                    # rest opaque
                end
            end
        end

        class Struct < Vips::Object::Struct
            include ImageLayout

            def initialize(ptr)
                Vips::log "Vips::Image::Struct.new: #{ptr}"
                super
            end

        end

        class ManagedStruct < Vips::Object::ManagedStruct
            include ImageLayout

            def initialize(ptr)
                Vips::log "Vips::Image::ManagedStruct.new: #{ptr}"
                super
            end

        end

        # handy for overloads ... want to be able to apply a function to an 
        # array or to a scalar
        def self.smap(x, &block)
            x.is_a?(Array) ? x.map {|y| smap(y, &block)} : block.(x)
        end

        def self.complex? format
            format_number = Vips::vips_enum_from_nick "complex?", 
                BAND_FORMAT_TYPE, format.to_s
            Vips::vips_band_format_iscomplex(format_number) != 0
        end

        def self.float? format
            format_number = Vips::vips_enum_from_nick "float?", 
                BAND_FORMAT_TYPE, format.to_s
            Vips::vips_band_format_isfloat(format_number) != 0
        end

        # run a complex operation on a complex image, or an image with an even
        # number of bands ... handy for things like running .polar on .index
        # images
        def self.run_cmplx(image, &block)
            original_format = image.format

            if not Image::complex? image.format
                if image.bands % 2 != 0
                    raise Error, "not an even number of bands"
                end

                if not Image::float? image.format
                    image = image.cast :float 
                end

                new_format = image.format == :double ? :dpcomplex : :complex
                image = image.copy :format => new_format, 
                    :bands => image.bands / 2
            end

            image = block.(image)

            if not Image::complex? original_format
                new_format = image.format == :dpcomplex ? :double : :float
                image = image.copy :format => new_format, 
                    :bands => image.bands * 2
            end

            image
        end

        # libvips 8.4 and earlier had a bug which swapped the args to the _const
        # enum operations
        def swap_const_args
            Vips::version(0) < 8 or 
                (Vips::version(0) == 8 and Vips::version(1) <= 4)
        end

        # handy for expanding enum operations
        def call_enum(name, other, enum)
            if other.is_a?(Vips::Image)
                Vips::Operation.call name.to_s, [self, other, enum]
            else
                args = swap_const_args ? 
                    [self, other, enum] : [self, enum, other]

                Vips::Operation.call name.to_s + "_const", args
            end
        end

        # Write can fail due to no file descriptors and memory can fill if
        # large objects are not collected fairly soon. We can't try a 
        # write and GC and retry on fail, since the write may take a 
        # long time and may not be repeatable.
        #
        # GCing before every write would have a horrible effect on 
        # performance, so as a compromise we GC every @@gc_interval writes.
        #                                 
        # ruby2.1 introduced a generational GC which is fast enough to be 
        # able to GC on every write.

        @@generational_gc = RUBY_ENGINE == "ruby" && RUBY_VERSION.to_f >= 2.1

        @@gc_interval = 100
        @@gc_countdown = @@gc_interval

        def write_gc
            if @@generational_gc  
                GC.start full_mark: false
            else
                @@gc_countdown -= 1
                if @@gc_countdown < 0
                    @@gc_countdown = @@gc_interval
                    GC.start  
                end
            end
        end

        public

        # Invoke a vips operation with {Vips::Operation::call}, using self as 
        # the first input argument. 
        #
        # @param name [String] vips operation to call
        # @return result of vips operation
        def method_missing(name, *args)
            Vips::Operation::call name.to_s, [self] + args
        end

        # Invoke a vips operation with {Vips::Operation::call}.
        def self.method_missing(name, *args)
            Vips::Operation::call name.to_s, args
        end

        # Return a new {Image} for a file on disc. This method can load
        # images in any format supported by vips. The filename can include
        # load options, for example:
        #
        # ```
        # image = Vips::new_from_file "fred.jpg[shrink=2]"
        # ```
        #
        # You can also supply options as a hash, for example:
        #
        # ```
        # image = Vips::new_from_file "fred.jpg", :shrink => 2
        # ```
        #
        # The full set of options available depend upon the load operation that 
        # will be executed. Try something like:
        #
        # ```
        # $ vips jpegload
        # ```
        #
        # at the command-line to see a summary of the available options for the
        # JPEG loader.
        #
        # Loading is fast: only enough of the image is loaded to be able to fill
        # out the header. Pixels will only be decompressed when they are needed.
        #
        # @!macro [new] vips.loadopts
        #   @param opts [Hash] set of options
        #   @option opts [Boolean] :disc (true) Open large images via a 
        #     temporary disc file
        #   @option opts [Vips::Access] :access (:random) Access mode for file
        #
        # @param name [String] the filename to load from
        # @macro vips.loadopts
        # @return [Image] the loaded image
        def self.new_from_file(name, opts = {})
            # very common, and Vips::vips_filename_get_filename will segv if we 
            # pass this
            raise Vips::Error, "filename is nil" if name == nil

            filename = Vips::vips_filename_get_filename name
            option_string = Vips::vips_filename_get_options name
            loader = Vips::vips_foreign_find_load filename
            raise Vips::Error if loader == nil

            Operation::call loader, [filename, opts], option_string
        end

        # Create a new {Image} for an image encoded, in a format such as
        # JPEG, in a memory string. Load options may be passed as
        # strings or appended as a hash. For example:
        #
        # ```
        # image = Vips::new_from_from_buffer memory_buffer, "shrink=2"
        # ```
        # 
        # or alternatively:
        #
        # ```
        # image = Vips::new_from_from_buffer memory_buffer, "", :shrink => 2
        # ```
        #
        # The options available depend on the file format. Try something like:
        #
        # ```
        # $ vips jpegload_buffer
        # ```
        #
        # at the command-line to see the available options. Not all loaders 
        # support load from buffer, but at least JPEG, PNG and
        # TIFF images will work. 
        #
        # Loading is fast: only enough of the image is loaded to be able to fill
        # out the header. Pixels will only be decompressed when they are needed.
        #
        # @param data [String] the data to load from
        # @param option_string [String] load options as a string
        # @macro vips.loadopts
        # @return [Image] the loaded image
        def self.new_from_buffer data, option_string, opts = {}
            loader = Vips::vips_foreign_find_load_buffer data, data.length
            raise Vips::Error if loader == nil

            Vips::Operation::call loader, [data, opts], option_string
        end

        def self.matrix_from_array width, height, array
            ptr = FFI::MemoryPointer.new :double, array.length
            ptr.write_array_of_double array
            image = Vips::vips_image_new_matrix_from_array width, height, 
                ptr, array.length
            Vips::Image.new image
        end

        # Create a new Image from a 1D or 2D array. A 1D array becomes an
        # image with height 1. Use `scale` and `offset` to set the scale and
        # offset fields in the header. These are useful for integer
        # convolutions. 
        #
        # For example:
        #
        # ```
        # image = Vips::new_from_array [1, 2, 3]
        # ```
        #
        # or
        #
        # ```
        # image = Vips::new_from_array [
        #     [-1, -1, -1],
        #     [-1, 16, -1],
        #     [-1, -1, -1]], 8
        # ```
        #
        # for a simple sharpening mask.
        #
        # @param array [Array] the pixel data as an array of numbers
        # @param scale [Real] the convolution scale
        # @param offset [Real] the convolution offset
        # @return [Image] the image
        def self.new_from_array array, scale = 1, offset = 0
            # we accept a 1D array and assume height == 1, or a 2D array
            # and check all lines are the same length
            if not array.is_a? Array
                raise Vips::Error, "Argument is not an array."
            end

            if array[0].is_a? Array
                height = array.length
                width = array[0].length
                if not array.all? {|x| x.is_a? Array}
                    raise Vips::Error, "Not a 2D array."
                end
                if not array.all? {|x| x.length == width}
                    raise Vips::Error, "Array not rectangular."
                end
                array = array.flatten
            else
                height = 1
                width = array.length
            end

            if not array.all? {|x| x.is_a? Numeric}
                raise Vips::Error, "Not all array elements are Numeric."
            end

            image = Vips::Image.matrix_from_array width, height, array
            raise Vips::Error if image == nil

            # be careful to set them as double
            image.set_type GLib::GDOUBLE_TYPE, 'scale', scale.to_f
            image.set_type GLib::GDOUBLE_TYPE, 'offset', offset.to_f

            return image
        end

        # A new image is created with the same width, height, format,
        # interpretation, resolution and offset as self, but with every pixel
        # set to the specified value.
        #
        # You can pass an array to make a many-band image, or a single value to
        # make a one-band image.
        #
        # @param value [Real, Array<Real>] value to put in each pixel
        # @return [Image] constant image
        def new_from_image value
            pixel = (Vips::Image.black(1, 1) + value).cast(format)
            image = pixel.embed(0, 0, width, height, :extend => :copy)
            image.copy :interpretation => interpretation,
                :xres => xres, :yres => yres,
                :xoffset => xoffset, :yoffset => yoffset
        end

        # Write this image to a file. Save options may be encoded in the
        # filename or given as a hash. For example:
        #
        # ```
        # image.write_to_file "fred.jpg[Q=90]"
        # ```
        #
        # or equivalently:
        #
        # ```
        # image.write_to_file "fred.jpg", :Q => 90
        # ```
        #
        # The full set of save options depend on the selected saver. Try 
        # something like:
        #
        # ```
        # $ vips jpegsave
        # ```
        #
        # to see all the available options for JPEG save. 
        #
        # @!macro [new] vips.saveopts
        #   @param opts [Hash] set of options
        #   @option opts [Boolean] :strip (false) Strip all metadata from image
        #   @option opts [Array<Float>] :background (0) Background colour to
        #     flatten alpha against, if necessary
        #
        # @param name [String] filename to write to
        def write_to_file name, opts = {}
            filename = Vips::vips_filename_get_filename name
            option_string = Vips::vips_filename_get_options name
            saver = Vips::vips_foreign_find_save filename
            if saver == nil
                raise Vips::Error, "No known saver for '#{filename}'."
            end

            Vips::Operation::call saver, [self, filename, opts]

            write_gc
        end

        # Write this image to a memory buffer. Save options may be encoded in 
        # the format_string or given as a hash. For example:
        #
        # ```
        # buffer = image.write_to_buffer ".jpg[Q=90]"
        # ```
        #
        # or equivalently:
        #
        # ```
        # image.write_to_buffer ".jpg", :Q => 90
        # ```
        #
        # The full set of save options depend on the selected saver. Try 
        # something like:
        #
        # ```
        # $ vips jpegsave
        # ```
        #
        # to see all the available options for JPEG save. 
        #
        # @param format_string [String] save format plus options
        # @macro vips.saveopts
        # @return [String] the image saved in the specified format
        def write_to_buffer format_string, opts = {}
            filename = Vips::vips_filename_get_filename format_string
            option_string = Vips::vips_filename_get_options format_string
            saver = Vips::vips_foreign_find_save_buffer filename
            if saver == nil
                raise Vips::Error, "No known saver for '#{filename}'."
            end

            buffer = Vips::Operation.call saver, [self, opts], option_string
            raise Vips::Error if buffer == nil

            write_gc

            return buffer
        end

        # Fetch a `GType` from an image. `GType` will be 0 for no such field.
        #
        # @see get
        # @param name [String] Metadata field to fetch
        # @return [Integer] GType
        def get_typeof name
            Vips::vips_image_get_typeof self, name
        end

        # Get a metadata item from an image. Ruby types are constructed 
        # automatically from the `GValue`, if possible. 
        #
        # For example, you can read the ICC profile from an image like this:
        #
        # ```
        # profile = image.get "icc-profile-data"
        # ```
        #
        # and profile will be an array containing the profile. 
        #
        # @param name [String] Metadata field to get
        # @return [Object] Value of field
        def get name
            gvalue = GLib::GValue.alloc
            result = Vips::vips_image_get self, name, gvalue
            if result != 0 
                raise Vips::Error
            end

            return gvalue.get
        end

        # Create a metadata item on an image, of the specifed type. Ruby types 
        # are automatically
        # transformed into the matching `GType`, if possible. 
        #
        # For example, you can use this to set an image's ICC profile:
        #
        # ```
        # x = y.set Vips::BLOB_TYPE, "icc-profile-data", profile
        # ```
        #
        # where `profile` is an ICC profile held as a binary string object.
        #
        # @see set
        # @param gtype [Integer] GType of item
        # @param name [String] Metadata field to set
        # @param value [Object] Value to set
        def set_type gtype, name, value
            gvalue = GLib::GValue.alloc
            gvalue.init gtype
            gvalue.set value
            Vips::vips_image_set self, name, gvalue
        end

        # Set the value of a metadata item on an image. The metadata item must 
        # already exist. Ruby types are automatically
        # transformed into the matching `GValue`, if possible. 
        #
        # For example, you can use this to set an image's ICC profile:
        #
        # ```
        # x = y.set "icc-profile-data", profile
        # ```
        #
        # where `profile` is an ICC profile held as a binary string object.
        #
        # @see set_type
        # @param name [String] Metadata field to set
        # @param value [Object] Value to set
        def set name, value
            set_type get_typeof(name), name, value
        end

        # Remove a metadata item from an image.
        #
        # @param name [String] Metadata field to remove
        def remove name
            Vips::vips_image_remove self, name
        end

        # compatibility: old name for get
        def get_value name
            get name
        end

        # compatibility: old name for set
        def set_value name, value
            set name, value
        end

        # Get image width, in pixels.
        #
        # @return [Integer] image width, in pixels
        def width
            get "width"
        end

        # Get image height, in pixels.
        #
        # @return [Integer] image height, in pixels
        def height
            get "height"
        end

        # Get number of image bands.
        #
        # @return [Integer] number of image bands
        def bands
            get "bands"
        end

        # Get image format.
        #
        # @return [Symbol] image format
        def format
            get "format"
        end

        # Get image interpretation.
        #
        # @return [Symbol] image interpretation
        def interpretation
            get "interpretation"
        end

        # Get image coding.
        #
        # @return [Symbol] image coding
        def coding
            get "coding"
        end

        # Get image filename, if any.
        #
        # @return [String] image filename
        def filename
            get "filename"
        end

        # Get image xoffset.
        #
        # @return [Integer] image xoffset
        def xoffset
            get "xoffset"
        end

        # Get image yoffset.
        #
        # @return [Integer] image yoffset
        def yoffset
            get "yoffset"
        end

        # Get image x resolution.
        #
        # @return [Float] image x resolution
        def xres
            get "xres"
        end

        # Get image y resolution.
        #
        # @return [Float] image y resolution
        def yres
            get "yres"
        end

        # Get scale metadata.
        #
        # @return [Float] image scale
        def scale
            return 1 if get_typeof("scale") == 0

            get "scale"
        end

        # Get offset metadata.
        #
        # @return [Float] image offset
        def offset
            return 0 if get_typeof("offset") == 0

            get "offset"
        end

        # Get the image size. 
        #
        # @return [Integer, Integer] image width and height
        def size
            [width, height]
        end

        def copy_memory
            new_image = Vips::vips_image_copy_memory self
            Vips::Image.new new_image
        end

        # Add an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] Thing to add to self
        # @return [Image] result of addition
        def +(other)
            other.is_a?(Vips::Image) ? 
                add(other) : linear(1, other)
        end

        # Subtract an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] Thing to subtract from self
        # @return [Image] result of subtraction
        def -(other)
            other.is_a?(Vips::Image) ? 
                subtract(other) : linear(1, Image::smap(other) {|x| x * -1})
        end

        # Multiply an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] Thing to multiply by self
        # @return [Image] result of multiplication
        def *(other)
            other.is_a?(Vips::Image) ? 
                multiply(other) : linear(other, 0)
        end

        # Divide an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] Thing to divide self by
        # @return [Image] result of division
        def /(other)
            other.is_a?(Vips::Image) ? 
                divide(other) : linear(Image::smap(other) {|x| 1.0 / x}, 0)
        end

        # Remainder after integer division with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] self modulo this
        # @return [Image] result of modulo
        def %(other)
            other.is_a?(Vips::Image) ? 
                remainder(other) : remainder_const(other)
        end

        # Raise to power of an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] self to the power of this
        # @return [Image] result of power
        def **(other)
            call_enum("math2", other, :pow)
        end

        # Integer left shift with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] shift left by this much
        # @return [Image] result of left shift
        def <<(other)
            call_enum("boolean", other, :lshift)
        end

        # Integer right shift with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] shift right by this much
        # @return [Image] result of right shift
        def >>(other)
            call_enum("boolean", other, :rshift)
        end

        # Integer bitwise OR with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] bitwise OR with this
        # @return [Image] result of bitwise OR 
        def |(other)
            call_enum("boolean", other, :or)
        end

        # Integer bitwise AND with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] bitwise AND with this
        # @return [Image] result of bitwise AND 
        def &(other)
            call_enum("boolean", other, :and)
        end

        # Integer bitwise EOR with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] bitwise EOR with this
        # @return [Image] result of bitwise EOR 
        def ^(other)
            call_enum("boolean", other, :eor)
        end

        # Equivalent to image ^ -1
        #
        # @return [Image] image with bits flipped
        def !
            self ^ -1
        end

        # Equivalent to image ^ -1
        #
        # @return [Image] image with bits flipped
        def ~
            self ^ -1
        end

        # @return [Image] image 
        def +@
            self
        end

        # Equivalent to image * -1
        #
        # @return [Image] negative of image 
        def -@
            self * -1
        end

        # Relational less than with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] relational less than with this
        # @return [Image] result of less than
        def <(other)
            call_enum("relational", other, :less)
        end

        # Relational less than or equal to with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] relational less than or
        #   equal to with this
        # @return [Image] result of less than or equal to
        def <=(other)
            call_enum("relational", other, :lesseq)
        end

        # Relational more than with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] relational more than with this
        # @return [Image] result of more than
        def >(other)
            call_enum("relational", other, :more)
        end

        # Relational more than or equal to with an image, constant or array. 
        #
        # @param other [Image, Real, Array<Real>] relational more than or
        #   equal to with this
        # @return [Image] result of more than or equal to
        def >=(other)
            call_enum("relational", other, :moreeq)
        end

        # Compare equality to nil, an image, constant or array.
        #
        # @param other [nil, Image, Real, Array<Real>] test equality to this
        # @return [Image] result of equality
        def ==(other)
            # for equality, we must allow tests against nil
            if other == nil
                false
            else
                call_enum("relational", other, :equal)
            end
        end

        # Compare inequality to nil, an image, constant or array.
        #
        # @param other [nil, Image, Real, Array<Real>] test inequality to this
        # @return [Image] result of inequality
        def !=(other)
            # for equality, we must allow tests against nil
            if other == nil
                true
            else
                call_enum("relational", other, :noteq)
            end
        end

        # Fetch bands using a number or a range
        #
        # @param index [Numeric, Range] extract these band(s)
        # @return [Image] extracted band(s)
        def [](index)
            if index.is_a? Range
                n = index.end - index.begin
                n += 1 if not index.exclude_end?
                extract_band index.begin, :n => n
            elsif index.is_a? Numeric
                extract_band index 
            else
                raise Vips::Error, "[] index is not range or numeric."
            end
        end

        # Convert to an Array. This will be very slow for large images. 
        #
        # @return [Array] array of Fixnum
        def to_a
            ar = Array.new(height)
            for y in 0...height
                ar[y] = Array.new(width)
                    for x in 0...width
                        ar[y][x] = getpoint(x, y)
                    end
            end

            return ar
        end

        # Return the largest integral value not greater than the argument.
        #
        # @return [Image] floor of image 
        def floor
            round :floor
        end

        # Return the smallest integral value not less than the argument.
        #
        # @return [Image] ceil of image 
        def ceil
            round :ceil
        end

        # Return the nearest integral value.
        #
        # @return [Image] rint of image 
        def rint
            round :rint
        end

        # AND the bands of an image together
        #
        # @return [Image] all bands ANDed together
        def bandand
            bandbool :and
        end

        # OR the bands of an image together
        #
        # @return [Image] all bands ORed together
        def bandor
            bandbool :or
        end

        # EOR the bands of an image together
        #
        # @return [Image] all bands EORed together
        def bandeor
            bandbool :eor
        end

        # Split an n-band image into n separate images.
        #
        # @return [Array<Image>] Array of n one-band images
        def bandsplit
            (0...bands).map {|i| extract_band(i)}
        end

        # Join a set of images bandwise.
        #
        # @param other [Image, Array<Image>, Real, Array<Real>] bands to append
        # @return [Image] many band image
        def bandjoin(other)
            if not other.is_a? Array
                other = [other]
            end

            # if other is just Numeric, we can use bandjoin_const
            not_all_real = (other.map {|x| not x.is_a?(Numeric)}).include?(true)

            if not_all_real
                Vips::Image.bandjoin([self] + other)
            else
                bandjoin_const(other)
            end
        end

        # Return the coordinates of the image maximum.
        #
        # @return [Real, Real, Real] maximum value, x coordinate of maximum, y
        #   coordinate of maximum
        def maxpos
            v, opts = max :x => true, :y => true
            x = opts['x']
            y = opts['y']
            return v, x, y
        end

        # Return the coordinates of the image minimum.
        #
        # @return [Real, Real, Real] minimum value, x coordinate of minimum, y
        #   coordinate of minimum
        def minpos
            v, opts = min :x => true, :y => true
            x = opts['x']
            y = opts['y']
            return v, x, y
        end

        # get the value of a pixel as an array
        #
        # @param x [Integer] x coordinate to sample
        # @param y [Integer] y coordinate to sample
        # @return [Array<Float>] the pixel values as an array
        def getpoint(x, y)
            # vips has an operation that does this, but we can't call it via
            # gobject-introspection 3.1 since it's missing array double
            # get
            #
            # remove this def when gobject-introspection updates
            crop(x, y, 1, 1).bandsplit.map(&:avg)
        end

        # a median filter
        #
        # @param size [Integer] size of filter window
        # @return [Image] result of median filter
        def median(size = 3)
            rank(size, size, (size * size) / 2)
        end

        # Return the real part of a complex image.
        #
        # @return [Image] real part of complex image
        def real
            complexget :real
        end

        # Return the imaginary part of a complex image.
        #
        # @return [Image] imaginary part of complex image
        def imag
            complexget :imag
        end

        # Return an image with rectangular pixels converted to polar. 
        #
        # The image
        # can be complex, in which case the return image will also be complex,
        # or must have an even number of bands, in which case pairs of 
        # bands are treated as (x, y) coordinates.
        #
        # @see xyz
        # @return [Image] image converted to polar coordinates
        def polar
            Image::run_cmplx(self) {|x| x.complex :polar}
        end

        # Return an image with polar pixels converted to rectangular.
        #
        # The image
        # can be complex, in which case the return image will also be complex,
        # or must have an even number of bands, in which case pairs of 
        # bands are treated as (x, y) coordinates.
        #
        # @see xyz
        # @return [Image] image converted to rectangular coordinates
        def rect
            Image::run_cmplx(self) {|x| x.complex :rect}
        end

        # Return the complex conjugate of an image.
        #
        # The image
        # can be complex, in which case the return image will also be complex,
        # or must have an even number of bands, in which case pairs of 
        # bands are treated as (x, y) coordinates.
        #
        # @return [Image] complex conjugate
        def conj
            Image::run_cmplx(self) {|x| x.complex :conj}
        end

        # Return the sine of an image in degrees.
        #
        # @return [Image] sine of each pixel
        def sin
            math :sin 
        end

        # Return the cosine of an image in degrees.
        #
        # @return [Image] cosine of each pixel
        def cos
            math :cos
        end

        # Return the tangent of an image in degrees.
        #
        # @return [Image] tangent of each pixel
        def tan
            math :tan
        end

        # Return the inverse sine of an image in degrees.
        #
        # @return [Image] inverse sine of each pixel
        def asin
            math :asin
        end

        # Return the inverse cosine of an image in degrees.
        #
        # @return [Image] inverse cosine of each pixel
        def acos
            math :acos
        end

        # Return the inverse tangent of an image in degrees.
        #
        # @return [Image] inverse tangent of each pixel
        def atan
            math :atan
        end

        # Return the natural log of an image.
        #
        # @return [Image] natural log of each pixel
        def log
            math :log
        end

        # Return the log base 10 of an image.
        #
        # @return [Image] base 10 log of each pixel
        def log10
            math :log10
        end

        # Return e ** pixel.
        #
        # @return [Image] e ** pixel
        def exp
            math :exp
        end

        # Return 10 ** pixel.
        #
        # @return [Image] 10 ** pixel
        def exp10
            math :exp10
        end

        # Flip horizontally.
        #
        # @return [Image] image flipped horizontally
        def fliphor
            flip :horizontal
        end

        # Flip vertically.
        #
        # @return [Image] image flipped vertically
        def flipver
            flip :vertical
        end

        # Erode with a structuring element.
        #
        # The structuring element must be an array with 0 for black, 255 for
        # white and 128 for don't care.
        #
        # @param mask [Image, Array<Real>, Array<Array<Real>>] structuring
        #   element
        # @return [Image] eroded image
        def erode(mask)
            morph mask, :erode
        end

        # Dilate with a structuring element.
        #
        # The structuring element must be an array with 0 for black, 255 for
        # white and 128 for don't care.
        #
        # @param mask [Image, Array<Real>, Array<Array<Real>>] structuring
        #   element
        # @return [Image] dilated image
        def dilate(mask)
            morph mask, :dilate
        end

        # Rotate by 90 degrees clockwise.
        #
        # @return [Image] rotated image
        def rot90
            rot :d90
        end

        # Rotate by 180 degrees clockwise.
        #
        # @return [Image] rotated image
        def rot180
            rot :d180
        end

        # Rotate by 270 degrees clockwise.
        #
        # @return [Image] rotated image
        def rot270
            rot :d270
        end

        # Select pixels from `th` if `self` is non-zero and from `el` if
        # `self` is zero. Use the `:blend` option to fade smoothly 
        # between `th` and `el`. 
        #
        # @param th [Image, Real, Array<Real>] true values
        # @param el [Image, Real, Array<Real>] false values
        # @param opts [Hash] set of options
        # @option opts [Boolean] :blend (false) Blend smoothly between th and el
        # @return [Image] merged image
        def ifthenelse(th, el, opts = {}) 
            match_image = [th, el, self].find {|x| x.is_a? Vips::Image}

            if not th.is_a? Vips::Image
                th = Operation::imageize match_image, th
            end
            if not el.is_a? Vips::Image
                el = Operation::imageize match_image, el
            end

            Vips::Operation.call "ifthenelse", [self, th, el, opts]
        end

        # Scale an image to uchar. This is the vips `scale` operation, but
        # renamed to avoid a clash with the `.scale` property.
        #
        # @param opts [Hash] Set of options
        # @return [Vips::Image] Output image
        def scaleimage(opts = {})
            Vips::Image.scale self, opts
        end

    end

    # This method generates yard comments for all the dynamically bound
    # vips operations. 
    #
    # Regenerate with something like: 
    #
    # ```
    # $ ruby > methods.rb
    # require 'vips'; Vips::generate_yard
    # ^D
    # ```

    def self.generate_yard
        # these have hand-written methods, see above
        no_generate = ["scale", "bandjoin", "ifthenelse"]

        # map gobject's type names to Ruby
        map_go_to_ruby = {
            "gboolean" => "Boolean",
            "gint" => "Integer",
            "gdouble" => "Float",
            "gfloat" => "Float",
            "gchararray" => "String",
            "VipsImage" => "Vips::Image",
            "VipsInterpolate" => "Vips::Interpolate",
            "VipsArrayDouble" => "Array<Double>",
            "VipsArrayInt" => "Array<Integer>",
            "VipsArrayImage" => "Array<Image>",
            "VipsArrayString" => "Array<String>",
        }

        generate_operation = lambda do |gtype, nickname, op|
            op_flags = op.get_flags
            return if (op_flags & OPERATION_DEPRECATED) != 0
            return if no_generate.include? nickname
            description = Vips::vips_object_get_description op

            # find and classify all the arguments the operator can take
            required_input = [] 
            optional_input = []
            required_output = [] 
            optional_output = []
            member_x = nil
            op.argument_map do |pspec, argument_class, argument_instance|
                arg_flags = argument_class[:flags]
                next if (arg_flags & ARGUMENT_CONSTRUCT) == 0 
                next if (arg_flags & ARGUMENT_DEPRECATED) != 0

                name = pspec[:name].gsub("-", "_")
                # 'in' as a param name confuses yard
                name = "im" if name == "in"
                gtype = pspec[:value_type]
                fundamental = GLib::g_type_fundamental gtype
                type_name = GLib::g_type_name gtype
                if map_go_to_ruby.include? type_name
                    type_name = map_go_to_ruby[type_name] 
                end
                if fundamental == GLib::GFLAGS_TYPE or 
                    fundamental == GLib::GENUM_TYPE
                    type_name =~ /Vips(.*)/
                    type_name = "Vips::" + $~[1]
                end
                blurb = GLib::g_param_spec_get_blurb pspec
                value = {:name => name, 
                         :flags => arg_flags, 
                         :gtype => gtype, 
                         :type_name => type_name, 
                         :blurb => blurb}

                if (arg_flags & ARGUMENT_INPUT) != 0 
                    if (arg_flags & ARGUMENT_REQUIRED) != 0 
                        # note the first required input image, if any ... we 
                        # will be a method of this instance
                        if not member_x and gtype == Vips::IMAGE_TYPE
                            member_x = value
                        else
                            required_input << value
                        end
                    else
                        optional_input << value
                    end
                end

                # MODIFY INPUT args count as OUTPUT as well
                if (arg_flags & ARGUMENT_OUTPUT) != 0 or
                    ((arg_flags & ARGUMENT_INPUT) != 0 and
                     (arg_flags & ARGUMENT_MODIFY) != 0)
                    if (arg_flags & ARGUMENT_REQUIRED) != 0 and
                        required_output << value
                    else
                        optional_output << value
                    end
                end

            end

            print "# @!method "
            print "self." if not member_x 
            print "#{nickname}("
            print required_input.map{|x| x[:name]}.join(", ")
            print ", " if required_input.length > 0
            puts "opts = {})"

            puts "#   #{description.capitalize}."

            required_input.each do |arg|
                puts "#   @param #{arg[:name]} [#{arg[:type_name]}] " +
                    "#{arg[:blurb]}"
            end

            puts "#   @param opts [Hash] Set of options"
            optional_input.each do |arg|
                puts "#   @option opts [#{arg[:type_name]}] :#{arg[:name]} " +
                    "#{arg[:blurb]}"
            end
            optional_output.each do |arg|
                print "#   @option opts [#{arg[:type_name]}] :#{arg[:name]}"
                puts " Output #{arg[:blurb]}"
            end

            print "#   @return ["
            if required_output.length == 0 
                print "nil" 
            elsif required_output.length == 1 
                print required_output.first[:type_name]
            elsif 
                print "Array<" 
                print required_output.map{|x| x[:type_name]}.join(", ")
                print ">" 
            end
            if optional_output.length > 0
                print ", Hash<Symbol => Object>"
            end
            print "] "
            print required_output.map{|x| x[:blurb]}.join(", ")
            if optional_output.length > 0
                print ", " if required_output.length > 0
                print "Hash of optional output items"
            end
            puts ""

            puts ""
        end

        generate_class = lambda do |gtype, a|
            nickname = Vips::nickname_find gtype

            if nickname
                begin
                    # can fail for abstract types
                    op = Vips::Operation.new_from_name nickname
                rescue
                end

                generate_operation.(gtype, nickname, op) if op
            end

            Vips::vips_type_map gtype, generate_class, nil
        end

        puts "module Vips"
        puts "  class Image"
        puts ""

        generate_class.(GLib::g_type_from_name("VipsOperation"), nil)

        puts "  end"
        puts "end"
    end

end
