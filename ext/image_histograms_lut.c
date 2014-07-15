#include "ruby_vips.h"

/*
 *  call-seq:
 *    im.histgr([band]) -> image
 *
 *  Find the histogram of *self*. If <i>band</i> is given, find the histogram
 *  for that band (producing a one-band histogram). If <i>band</i> is not given,
 *  find the histogram for all bands (producing an n-band histogram).
 *
 *  *self* must be u8 or u16. The output image is always u32.
 */

VALUE
img_histgr(int argc, VALUE *argv, VALUE obj)
{
	VALUE v_bandno;
	int bandno;
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

	rb_scan_args(argc, argv, "01", &v_bandno);
	bandno = NIL_P(v_bandno) ? -1 : NUM2INT(v_bandno);

    if (im_histgr(im, im_new, bandno))
        vips_lib_error();

    return new;  
}

/*
 *  call-seq:
 *     im.histnd(bins) -> image
 *
 *  Make a one, two or three dimensional histogram of a 1, 2 or 3 band image.
 *  Divide each axis into a certain number of bins .. ie. output is 1 x bins,
 *  bins x bins, or bins x bins x bins bands. uchar and ushort only.
 */

VALUE
img_histnd(VALUE obj, VALUE bins)
{
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

    if (im_histnD(im, im_new, NUM2INT(bins)))
        vips_lib_error();

    return new;  
}

/*
 *  call-seq:
 *     im.hist_indexed(other_image) -> image
 *
 *  Make a histogram of <i>other_image</i>, but use *self* to pick the bins. In
 *  other words, element zero in the output image contains the sum of all the
 *  pixels in <i>other_image</i> whose corresponding pixel in *self* is zero.
 *
 *  *self* must have just one band and be u8 or u16. <i>other_image</i> must be
 *  non-complex. The output image always has the same size and format as
 *  <i>other_image</i>.
 *
 *  This operation is useful in conjunction with Image#label_regions. You can
 *  use it to find the centre of gravity of blobs in an image, for example.
 */

VALUE
img_hist_indexed(VALUE obj, VALUE obj2)
{
	RUBY_VIPS_BINARY(im_hist_indexed);
}

/*
 *  call-seq:
 *     Image.identity(bands) -> image
 *
 *  Creates a image file with Xsize=256, Ysize=1, Bands=<i>bands</i>,
 *  BandFmt= :UCHAR, Type=:HISTOGRAM.
 *
 *  The created image consist of a <i>bands</i>-bands linear lut and is the
 *  basis for building up look-up tables.
 */

VALUE
img_s_identity(VALUE obj, VALUE bands)
{
	OutPartial(new, data, im);

    if (im_identity(im, NUM2INT(bands)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     Image.identity_ushort(size) -> image
 *
 *  As Image.identity, but make a ushort LUT. ushort LUTs can be up to 65536
 *  elements - <i>size</i> is the number of elements required.
 *
 *  The created image consist of a <i>bands</i>-bands linear lut and is the
 *  basis for building up look-up tables.
 */

VALUE
img_s_identity_ushort(VALUE obj, VALUE bands, VALUE sz)
{
	OutPartial(new, data, im);

    if (im_identity_ushort(im, NUM2INT(bands), NUM2INT(sz)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     Image.invertlut(input, lut_size) -> image
 *
 *  Given a <i>input</i> of target values and real values, generate a LUT which
 *  will map reals to targets. Handy for linearising images from measurements of
 *  a colour chart. All values in [0,1]. Piecewise linear interpolation,
 *  extrapolate head and tail to 0 and 1.
 *
 *  Eg. input like this:
 *
 *   input = [
 *     [0.2, 0.2, 0.3, 0.1],
 *     [0.2, 0.4, 0.4, 0.2],
 *     [0.7, 0.5, 0.6, 0.3]
 *   ]
 *
 *  Means a patch with 10% reflectance produces an image with 20% in channel 1,
 *  30% in channel 2, and 10% in channel 3, and so on.
 *
 *  Inputs don't need to be sorted (we do that). Generate any precision LUT,
 *  typically you might ask for 256 elements.
 *
 *  It won't work too well for non-monotonic camera responses.
 *
 *  <i>input</i> can be an array or a Mask object.
 */

VALUE
img_s_invertlut(VALUE obj, VALUE input, VALUE lut_size)
{
    DOUBLEMASK *dmask;
	OutPartial(new, data, im);

    mask_arg2mask(input, NULL, &dmask);

    if (im_invertlut(dmask, im, NUM2INT(lut_size)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     Image.buildlut(input) -> image
 *
 *  This operation builds a lookup table from a set of points. Intermediate
 *  values are generated by piecewise linear interpolation.
 *
 *  For example, consider this 2 x 2 matrix of (x, y) coordinates:
 *
 *    input = [
 *      [  0,   0],
 *      [255, 100]
 *    ]
 *    im = Image.invertlut(input)
 *
 *  We then generate an image with the following pixel values:
 *
 *    im[0, 0] # => 0
 *    im[0, 1] # => 0.4
 *    # ...
 *    im[0, 255] # => 100
 *
 *  This is then written as the output image, with the left column giving the
 *  index in the image to place the value.
 *
 *  The (x, y) points don't need to be sorted: we do that. You can have several
 *  Ys, each becomes a band in the output LUT. You don't need to start at zero,
 *  any integer will do, including negatives.
 */

VALUE
img_s_buildlut(VALUE obj, VALUE input)
{
    DOUBLEMASK *dmask;
	OutPartial(new, data, im);

    mask_arg2mask(input, NULL, &dmask);

    if (im_buildlut(dmask, im))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     im.project -> image
 *
 *  Find the horizontal and vertical projections of an image, ie. the sum
 *  of every row of pixels, and the sum of every column of pixels. The output
 *  format is uint, int or double, depending on the input format.
 *
 *  Non-complex images only.
 */

VALUE
img_project(VALUE obj)
{
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);
	OutImg(obj, new2, data_new2, im_new2);

    if (im_project(im, im_new, im_new2))
        vips_lib_error();

    return rb_ary_new3(2, new, new2);
}

/*
 *  call-seq:
 *     im.histnorm -> image
 *
 *  Normalise histogram ... normalise range to make it square (ie. max ==
 *  number of elements). Normalise each band separately.
 */

VALUE
img_histnorm(VALUE obj)
{
	RUBY_VIPS_UNARY(im_histnorm);
}

/*
 *  call-seq:
 *     im.histcum -> image
 *
 *  Form cumulative histogram.
 */

VALUE
img_histcum(VALUE obj)
{
	RUBY_VIPS_UNARY(im_histcum);
}

/*
 *  call-seq:
 *     im.histeq -> image
 *
 *  Histogram equalisation: normalised cumulative histogram.
 */

VALUE
img_histeq(VALUE obj)
{
	RUBY_VIPS_UNARY(im_histeq);
}

/*
 *  call-seq:
 *     im.histspec(other_image) -> image
 *
 *  Creates a lut which, when applied to the image from which histogram *self*
 *  was formed, will produce an image whose PDF matches that of the image from
 *  which <i>other_image</i> was formed.
 */

VALUE
img_histspec(VALUE obj, VALUE obj2)
{
	RUBY_VIPS_BINARY(im_histspec);
}

/*
 *  call-seq:
 *     im.maplut(lut) -> image
 *
 *  Map an image through another image acting as a LUT (Look Up Table).
 *  The lut may have any type, and the output image will be that type.
 *
 *  The input image will be cast to one of the unsigned integer types, that is,
 *  band format :UCHAR, :USHORT or :UINT.
 *
 *  If <i>lut</i> is too small for the input type (for example, if *self* is
 *  band format :UCHAR but <i>lut</i> only has 100 elements), the lut is padded
 *  out by copying the last element. Overflows are reported at the end of
 *  computation.
 *
 *  If <i>lut</i> is too large, extra values are ignored.
 *
 *  If <i>lut</i> has one band, then all bands of *self* pass through it. If
 *  <i>lut</i> has same number of bands as *self*, then each band is mapped
 *  separately. If *self* has one band, then @lut may have many bands and the
 *  output will have the same number of bands as <i>lut</i>.
 */

VALUE
img_maplut(VALUE obj, VALUE obj2)
{
	GetImg(obj, data, im);
	GetImg(obj2, data2, im2);
	OutImg2(obj, obj2, new, data_new, im_new);

	if (im_maplut(im, im_new, im2))
		vips_lib_error();

	return new;
}

/*
 *  call-seq:
 *     im.histplot -> image
 *
 *  Plot a 1 by any or any by 1 image as a max by any or any by max image using
 *  these rules:
 *
 *  * unsigned char max is always 256
 *  * other unsigned integer types output 0 - maxium value of *self*.
 *  * signed int types - min moved to 0, max moved to max + min.
 *  * float types - min moved to 0, max moved to any (square output).
 */

VALUE
img_histplot(VALUE obj)
{
	RUBY_VIPS_UNARY(im_histplot);
}

/*
 *  call-seq:
 *     im.monotonic? -> true or false
 *
 *  Test *self* for monotonicity. Returns true if *self* is monotonic.
 */

VALUE
img_monotonic_p(VALUE obj)
{
    int ret;
	GetImg(obj, data, im);

	if( im_ismonotonic(im, &ret) )
	    vips_lib_error();

	return( ret == 0 ? Qfalse : Qtrue );
}

/*
 *  call-seq:
 *     im.hist([band])
 *
 *  Find and plot the histogram of *self*. If <i>band</i> is not given, plot all
 *  bands. Otherwise plot the specified band.
 */

VALUE
img_hist(int argc, VALUE *argv, VALUE obj)
{
	VALUE v_bandno;
	int bandno;
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

	rb_scan_args(argc, argv, "01", &v_bandno);
	bandno = NIL_P(v_bandno) ? -1 : NUM2INT(v_bandno);

    if (im_hist(im, im_new, bandno))
        vips_lib_error();

    return new;  
}

/*
 *  call-seq:
 *     im.hsp(other_image) -> image
 *
 *  Maps *self* to the output image,, adjusting the histogram to match image
 *  <i>other_image</i>.
 *
 *  Both images should have the same number of bands.
 */

VALUE
img_hsp(VALUE obj, VALUE obj2)
{
	RUBY_VIPS_BINARY(im_hsp);
}

/*
 *  call-seq:
 *     im.gammacorrect(exponent) -> image
 *
 *  Gamma-correct an 8- or 16-bit unsigned image with a lookup table. The
 *  output format is the same as the input format.
 */

VALUE
img_gammacorrect(VALUE obj, VALUE exponent)
{
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

    if (im_gammacorrect(im, im_new, NUM2DBL(exponent)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     im.mpercent_hist(percent) -> number
 *
 *  Just like Image#mpercent, except it works on an image histogram. Handy if
 *  you want to run Image#mpercent several times without having to recompute the
 *  histogram each time.
 */

VALUE
img_mpercent_hist(VALUE obj, VALUE percent)
{
#if ATLEAST_VIPS( 7, 22 )
    int ret;
	GetImg(obj, data, im);
    
    if (im_mpercent_hist(im, NUM2DBL(percent), &ret))
        vips_lib_error();

    return INT2NUM(ret);
#else
    rb_raise(eVIPSError, "This operation is not supported by your version of VIPS");
#endif
}

/*
 *  call-seq:
 *     im.mpercent(percent) -> number
 *
 *  Returns the threshold above which there are <i>percent</i> values of *self*.
 *  If for example percent=.1, the number of pels of the input image with values
 *  greater than the returned int will correspond to 10% of all pels of the
 *  image.
 *
 *  The function works for uchar and ushort images only.  It can be used to
 *  threshold the scaled result of a filtering operation.
 */

VALUE
img_mpercent(VALUE obj, VALUE percent)
{
    int ret;
	GetImg(obj, data, im);
    
    if (im_mpercent(im, NUM2DBL(percent), &ret))
        vips_lib_error();

    return INT2NUM(ret);
}

/*
 *  call-seq:
 *     im.heq([band]) -> image
 *
 *  Histogram-equalise *self*. Equalise using band <i>band</i>, or if not given,
 *  equalise all bands.
 */

VALUE
img_heq(int argc, VALUE *argv, VALUE obj)
{
	VALUE v_bandno;
	int bandno;
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

	rb_scan_args(argc, argv, "01", &v_bandno);
	bandno = NIL_P(v_bandno) ? -1 : NUM2INT(v_bandno);

    if (im_heq(im, im_new, bandno))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     im.lhisteq(xwin, ywin) -> image
 *
 *  Performs local histogram equalisation on *self* using a window of size
 *  <i>xwin</i> by <i>ywin</i> centered on the input pixel. Works only on
 *  monochrome images.
 *
 *  The output image is the same size as the input image. The edge pixels are
 *  created by copy edge pixels of the input image outwards.
 */

VALUE
img_lhisteq(VALUE obj, VALUE xwin, VALUE ywin)
{
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

    if (im_lhisteq(im, im_new, NUM2INT(xwin), NUM2INT(ywin)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     im.stdif(a, m0, b, s, xwin, ywin) -> image
 *
 *  Preforms statistical differencing according to the formula given in page 45
 *  of the book "An Introduction to Digital Image Processing" by Wayne Niblack.
 *  This transformation emphasises the way in which a pel differs statistically
 *  from its neighbours. It is useful for enhancing low-contrast images with
 *  lots of detail, such as X-ray plates.
 *
 *  At point (i,j) the output is given by the equation:
 *
 *    vout(i,j) = a * m0 + (1 - a) * meanv +
 *        (vin(i,j) - meanv) * (b * s0) / (s0 + b * stdv)
 *
 *  Values <i>a</i>, <i>m0</i>, <i>b</i> and <i>s0</i> are entered, while meanv
 *  and stdv are the values calculated over a moving window of size <i>xwin</i>,
 *  <i>ywin</i> centred on pixel (i,j).
 *
 *  <i>m0</i> is the new mean, <i>a</i> is the weight given to it. <i>s0</i> is
 *  the new standard deviation, <i>b</i> is the weight given to it.
 *
 *  Try:
 *
 *    im.stdif(0.5, 128, 0.5, 50, 11, 11)
 *
 *  The operation works on one-band uchar images only, and writes a one-band
 *  uchar image as its result. The output image has the same size as the
 *  input.
 */

VALUE
img_stdif(VALUE obj,
	VALUE a, VALUE m0, VALUE b, VALUE s0, VALUE xwin, VALUE ywin)
{
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

    if (im_stdif(im, im_new,
		NUM2DBL(a), NUM2DBL(m0), NUM2DBL(b), NUM2DBL(s0),
		NUM2INT(xwin), NUM2INT(ywin)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     Image.tone_build_range(in_max, out_max, lb, lw, ps, pm, ph, s, m, h) -> image
 *
 *  Generates a tone curve for the adjustment of image levels. It is mostly
 *  designed for adjusting the L* part of a LAB image in way suitable for print
 *  work, but you can use it for other things too.
 *
 *  The curve is an unsigned 16-bit image with (<i>in_max</i> + 1) entries, each
 *  in the range [0, <i>out_max</i>].
 *
 *  <i>lb</i>, <i>lw</i> are expressed as 0-100, as in LAB colour space. You
 *  specify the scaling for the input and output images with the <i>in_max</i>
 *  and <i>out_max</i> parameters.
 */

VALUE
img_s_tone_build_range(VALUE obj,
	VALUE in_max, VALUE out_max,
	VALUE lb, VALUE lw, VALUE ps, VALUE pm, VALUE ph, VALUE s, VALUE m, VALUE h)
{
	OutPartial(new, data, im);

    if (im_tone_build_range(im,
		NUM2DBL(in_max), NUM2DBL(out_max),
		NUM2DBL(lb), NUM2DBL(lw), NUM2DBL(ps), NUM2DBL(pm), NUM2DBL(ph),
		NUM2DBL(s), NUM2DBL(m), NUM2DBL(h)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     Image.tone_build(lb, lw, ps, pm, ph, s, m, h) -> image
 *
 *  As Image#tone_build_range, but set 32767 and 32767 as values for
 *  <i>in_max</i> and <i>out_max</i>. This makes a curve suitable for correcting
 *  LABS images, the most common case.
 */

VALUE
img_s_tone_build(VALUE obj,
	VALUE lb, VALUE lw, VALUE ps, VALUE pm, VALUE ph, VALUE s, VALUE m, VALUE h)
{
	OutPartial(new, data, im);

    if (im_tone_build(im,
		NUM2DBL(lb), NUM2DBL(lw), NUM2DBL(ps), NUM2DBL(pm), NUM2DBL(ph),
		NUM2DBL(s), NUM2DBL(m), NUM2DBL(h)))
        vips_lib_error();

    return new;
}

/*
 *  call-seq:
 *     im.tone_analyse(ps, pm, ph, s, m, h) -> image
 *
 *  As Image#tone_build, but analyse the histogram of *self* and use it to pick
 *  the 0.1% and 99.9% points for <i>lb</i> and <i>lw</i>.
 */

VALUE
img_tone_analyse(VALUE obj,
	VALUE ps, VALUE pm, VALUE ph, VALUE s, VALUE m, VALUE h)
{
#if ATLEAST_VIPS( 7, 23 )
	GetImg(obj, data, im);
	OutImg(obj, new, data_new, im_new);

    if (im_tone_analyse(im, im_new,
		NUM2DBL(ps), NUM2DBL(pm), NUM2DBL(ph),
		NUM2DBL(s), NUM2DBL(m), NUM2DBL(h)) )
        vips_lib_error();

    return new;
#else
    rb_raise(eVIPSError, "This operation is not supported by your version of VIPS");
#endif
}
