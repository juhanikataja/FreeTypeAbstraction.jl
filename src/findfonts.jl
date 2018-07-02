
if Sys.isapple()
    function _font_paths()
        [
            "/Library/Fonts", # Additional fonts that can be used by all users. This is generally where fonts go if they are to be used by other applications.
            "~/Library/Fonts", # Fonts specific to each user.
            "/Network/Library/Fonts", # Fonts shared for users on a network
        ]
    end
elseif Sys.iswindows()
    _font_paths() = [joinpath(ENV["WINDIR"], "fonts")]
else
    function add_recursive(result, path)
        for p in readdir(path)
            pabs = joinpath(path, p)
            if isdir(pabs)
                push!(result, pabs)
                add_recursive(result, pabs)
            end
        end
    end
    function _font_paths()
        result = String[]
        for p in ("/usr/share/fonts", joinpath(homedir(), "/.fonts"), "/usr/local/share/fonts",)
            if isdir(p)
                add_recursive(result, p)
            end
        end
        result
    end
end


freetype_extensions() = (".FON", ".OTC", ".FNT", ".BDF", ".PFR", ".OTF", ".TTF", ".TTC", ".CFF", ".WOFF")
function freetype_can_read(font::String)
    fontname, ext = splitext(font)
    uppercase(ext) in freetype_extensions()
end

function loaded_faces()
    if isempty(loaded_fonts)
        for path in fontpaths()
            for font in readdir(path)
                # There doesn't really seem to be a reliable pattern here.
                # there are fonts that should be supported and dont load
                # and fonts with an extension not on the FreeType website, which
                # load just fine. So we just try catch it!
                #freetype_can_read(font) || continue
                fpath = joinpath(path, font)
                try
                    push!(loaded_fonts, newface(fpath)[1])
                catch
                end
            end
        end
    end
    return loaded_fonts
end


function match_font(face, name, italic, bold)
    ft_rect = unsafe_load(face)
    ft_rect.family_name == C_NULL && return false
    fname = lowercase(unsafe_string(ft_rect.family_name))
    italic = italic == ((ft_rect.style_flags & FreeType.FT_STYLE_FLAG_ITALIC) > 0)
    bold = bold == ((ft_rect.style_flags & FreeType.FT_STYLE_FLAG_BOLD) > 0)
    return contains(fname, lowercase(name)) # && italic && bold
end
function findfont(name::String; italic = false, bold = false, additional_fonts::String = "")
    font_folders = copy(fontpaths())
    isempty(additional_fonts) || push!(font_folders, additional_fonts)
    for folder in font_folders
        for font in readdir(folder)
            fpath = joinpath(folder, font)
            face = try
                newface(fpath)[]
            catch e
                continue
            end
            match_font(face, name, italic, bold) && return face
            FT_Done_Face(face)
        end
    end
    return nothing
end