-- IDE mouse interaction: clicking a file opens it in Helix, clicking a folder enters it
function Entity:click(event, up)
    if up or event.is_middle then
        return
    end

    ya.emit("reveal", { self._file.url })
    if self._file.cha.is_dir then
        ya.emit("enter", {})
    else
        ya.emit("open", { hovered = true })
    end
end
