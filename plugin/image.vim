command! -nargs=0 Image call DisplayImage()

if !has("python")
    echo "image.vim requires python support"
    finish
endif

au BufWinEnter,VimResized,WinEnter *.png,*.jpg,*.jpeg,*.gif :call DisplayImage()
au QuitPre *.png,*.jpg,*.jpeg,*.gif :call CloseImage()
au CursorHold *.gif :call DisplayImage()
au BufHidden *.png,*.jpg,*.jpeg,*.gif :call HideImage()
au BufLeave,WinLeave *.png,*.jpg,*.jpeg,*.gif exe "set updatetime=".g:original_updatetime

let g:original_updatetime = &updatetime
function! CloseImage()
    call clearmatches()
    bd!
    let w:image_frame = 0
    exe "set updatetime=".g:original_updatetime
endfunction

function! HideImage()
    call clearmatches()
    let w:image_frame = 0
    let w:gif_paused = 1
    exe "set updatetime=".g:original_updatetime
endfunction

function! DisplayImage()
set nowrap
set nonumber
set norelativenumber
set buftype=nofile
set noswapfile

if !exists('w:image_frame')
    let w:image_frame = 0
endif

if !exists('w:gif_paused')
    let w:gif_paused = 0
elseif w:gif_paused == 1
    return
endif

python << EOF
from __future__ import division
import vim
from PIL import Image

def gethextriplet(rgb):
    r = 17 * int(rgb[0]/16)
    g = 17 * int(rgb[1]/16)
    b = 17 * int(rgb[2]/16)
    if len(rgb) > 3:
        a = rgb[3]
    else:
        a = 255
    return (r,g,b, a)

def getwebsafe(rgb):
    rw = 51 * ((int(rgb[0])+25)//51)
    gw = 51 * ((int(rgb[1])+25)//51)
    bw = 51 * ((int(rgb[2])+25)//51)
    if len(rgb) > 3:
        a = rgb[3]
    else:
        a = 255
    return (rw,gw,bw, a)

def getAsciiImage(imageFile, maxWidth, maxHeight):
    try:
        img = Image.open(imageFile)
    except:
        exit("Cannot open image %s" % imageFile)

    frame = int(vim.eval("w:image_frame"))

    if imageFile.endswith(".gif"):
        try:
            img.seek(frame)
        except EOFError:
            vim.command("let w:image_frame = 0")
            frame = 0
            img.seek(0)
        vim.command("set updatetime=50")
    img = img.convert("RGBA")

    # We want to stretch the image a little wide to compensate for
    # the rectangular/taller shape of fonts.
    # The width:height ratio will be 2:1
    width, height = img.size
    width = width * 2

    scale = maxWidth / width
    if scale > 1:
        scale = 1
    imageAspectRatio = width / height
    winAspectRatio = maxWidth / maxHeight

    if winAspectRatio > imageAspectRatio:
        scale = scale * (imageAspectRatio / winAspectRatio)

    scaledWidth = int(scale * width)
    scaledHeight = int(scale * height)

    # Use the original image size to scale the image
    img = img.resize((scaledWidth, scaledHeight))
    pixels = img.load()

    colorPalette = "@%#*+=-:. "
    lencolor = len(colorPalette)

    # Delete the current buffer so that we dont overwrite the real image file
    # get a new buffer
    # enew is safe enough since we did not specified a buftype, so we
    # cannot save this

    # clear the buffer
    vim.current.buffer[:] = None
    vim.command("call clearmatches()")

    mycolorpalette = {}
    vim.command("hi Transparent guifg=default guibg=default")
    for y in range(scaledHeight):
        asciiImage = ""
        for x in range(scaledWidth):
            rgb = pixels[x, y]

            rgb = gethextriplet(rgb)
            alpha = 255
            if len(rgb) == 4:
                alpha = rgb[3]
            if alpha == 0:
                colorname = "Transparent"
            else:
                rgbstring = '#%02x%02x%02x' % (rgb[0], rgb[1], rgb[2])
                if rgbstring not in mycolorpalette:
                    colorname = "RGBColor" + rgbstring[1:]
                    mycolorpalette[rgbstring] = colorname
                    vim.command("hi " + colorname + " guifg=" + rgbstring+ " guibg=" + rgbstring)
                else:
                    colorname = mycolorpalette[rgbstring]
            vim.command('call matchaddpos("' + colorname + '", [[' + str(y+2) + ", " + str(x+1) + "]])")
            if colorname == "Transparent":
                asciiImage += " "
            else:
                asciiImage += colorPalette[int(sum(rgb) / len(rgb) / 256 * lencolor)]
        vim.current.buffer.append(asciiImage)

imagefile = vim.eval("expand('%:p')")

width = vim.current.window.width
height = vim.current.window.height

getAsciiImage(imagefile, width, height)

EOF

let w:image_frame += 1
endfunction
