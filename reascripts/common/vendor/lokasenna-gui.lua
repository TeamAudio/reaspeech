GUI = {}
------------------------------------


-- A basic crash handler, just to add some helpful detail
-- to the Reaper error message.
GUI.crash = function (errObject, skipMsg)

  if GUI.oncrash then GUI.oncrash() end

  local by_line = "([^\r\n]*)\r?\n?"
  local trim_path = "[\\/]([^\\/]-:%d+:.+)$"
  local err = errObject   and string.match(errObject, trim_path)
                          or  "Couldn't get error message."

  local trace = debug.traceback()
  local tmp = {}
  for line in string.gmatch(trace, by_line) do

      local str = string.match(line, trim_path) or line

      tmp[#tmp + 1] = str

  end

  local name = ({reaper.get_action_context()})[2]:match("([^/\\_]+)$")

  local ret = skipMsg and 6 or reaper.ShowMessageBox(name.." has crashed!\n\n"..
                              "Would you like to have a crash report printed "..
                              "to the Reaper console?",
                              "Oops", 4)

  if ret == 6 then

      reaper.ShowConsoleMsg(  "Error: "..err.."\n\n"..
                              (GUI.error_message and tostring(GUI.error_message).."\n\n" or "") ..
                              "Stack traceback:\n\t"..table.concat(tmp, "\n\t", 2).."\n\n"..
                              "Lokasenna_GUI:\n\t"..(GUI.version or "v2.x").."\n"..
                              "Reaper:\n\t"..reaper.GetAppVersion().."\n"..
                              "Platform:\n\t"..reaper.GetOS())
  end

  GUI.quit = true
  gfx.quit()
end




------------------------------------
-------- Module loading ------------
------------------------------------


-- I hate working with 'requires', so I've opted to do it this way.
-- This also works much more easily with my Script Compiler.
GUI.req = function(file)

    if missing_lib then return function () end end

    local file_path = ( (file:sub(2, 2) == ":" or file:sub(1, 1) == "/") and ""
                                                                          or  GUI.lib_path )
                        .. file

    local ret, err = loadfile(file_path)
    if not ret then
        local ret = reaper.ShowMessageBox(  "Couldn't load " .. file ..
                                "\n\n" ..
                                "Error message:\n" .. tostring(err) ..
                                "\n\n" ..
                                "Please make sure you have the newest version of Lokasenna_GUI. " ..
                                "If you're using ReaPack, select Extensions -> ReaPack -> Synchronize Packages. " ..
                                "\n\n" ..
                                "If this error persists, contact the script author." ..
                                "\n\n" ..
                                "Would you like to have a crash report printed "..
                                "to the Reaper console?"
                                , "Library error", 4
                            )
        GUI.error_message = tostring(err)
        if ret == 6 then GUI.crash(nil, true) end
        missing_lib = true
        return function () end

    else
        return ret
    end

end




------------------------------------
-------- Main functions ------------
------------------------------------


-- All elements are stored here. Don't put them anywhere else, or
-- Main will never find them.
GUI.elms = {}

-- On each draw loop, only layers that are set to true in this table
-- will be redrawn; if false, it will just copy them from the buffer
-- Set [0] = true to redraw everything.
GUI.redraw_z = {}

-- Maintain a list of all GUI elements, sorted by their z order
-- Also removes any elements with z = -1, for automatically
-- cleaning things up.
GUI.elms_list = {}
GUI.z_max = 0
GUI.update_elms_list = function (init)

    local z_table = {}
    GUI.z_max = 0

    for key, __ in pairs(GUI.elms) do

        local z = GUI.elms[key].z or 5

        -- Delete elements if the script asked to
        if z == -1 then

            GUI.elms[key]:ondelete()
            GUI.elms[key] = nil

        else

            if z_table[z] then
                table.insert(z_table[z], key)

            else
                z_table[z] = {key}

            end

        end

        if init then

            GUI.elms[key]:init()

        end

        GUI.z_max = math.max(z, GUI.z_max)

    end

    GUI.elms_list = z_table

end

GUI.elms_hide = {}
GUI.elms_freeze = {}




GUI.Init = function ()
    xpcall( function()


        -- Create the window
        gfx.clear = reaper.ColorToNative(table.unpack(GUI.colors.wnd_bg))

        if not GUI.x then GUI.x = 0 end
        if not GUI.y then GUI.y = 0 end
        if not GUI.w then GUI.w = 640 end
        if not GUI.h then GUI.h = 480 end

        if GUI.anchor and GUI.corner then
            GUI.x, GUI.y = GUI.get_window_pos(  GUI.x, GUI.y, GUI.w, GUI.h,
                                                GUI.anchor, GUI.corner)
        end

        gfx.init(GUI.name, GUI.w, GUI.h, GUI.dock or 0, GUI.x, GUI.y)


        GUI.cur_w, GUI.cur_h = gfx.w, gfx.h

        -- Measure the window's title bar, in case we need it
        local __, __, wnd_y, __, __ = gfx.dock(-1, 0, 0, 0, 0)
        local __, gui_y = gfx.clienttoscreen(0, 0)
        GUI.title_height = gui_y - wnd_y


        -- Initialize a few values
        GUI.last_time = 0
        GUI.mouse = {

            x = 0,
            y = 0,
            cap = 0,
            down = false,
            wheel = 0,
            lwheel = 0

        }

        -- Store which element the mouse was clicked on.
        -- This is essential for allowing drag behaviour where dragging affects
        -- the element position.
        GUI.mouse_down_elm = nil
        GUI.rmouse_down_elm = nil
        GUI.mmouse_down_elm = nil


        -- Convert color presets from 0..255 to 0..1
        for i, col in pairs(GUI.colors) do
            col[1], col[2], col[3], col[4] =    col[1] / 255, col[2] / 255,
                                                col[3] / 255, col[4] / 255
        end

        -- Initialize the tables for our z-order functions
        GUI.update_elms_list(true)

        if GUI.exit then reaper.atexit(GUI.exit) end

        GUI.gfx_open = true

    end, GUI.crash)
end

GUI.Main = function ()
    xpcall( function ()

        if GUI.Main_Update_State() == 0 then return end

        GUI.Main_Update_Elms()

        -- If the user gave us a function to run, check to see if it needs to be
        -- run again, and do so.
        if GUI.func then

            local new_time = reaper.time_precise()
            if new_time - GUI.last_time >= (GUI.freq or 1) then
                GUI.func()
                GUI.last_time = new_time

            end
        end


        -- Maintain a list of elms and zs in case any have been moved or deleted
        GUI.update_elms_list()


        GUI.Main_Draw()

    end, GUI.crash)
end


GUI.Main_Update_State = function()

    -- Update mouse and keyboard state, window dimensions
    if GUI.mouse.x ~= gfx.mouse_x or GUI.mouse.y ~= gfx.mouse_y then

        GUI.mouse.lx, GUI.mouse.ly = GUI.mouse.x, GUI.mouse.y
        GUI.mouse.x, GUI.mouse.y = gfx.mouse_x, gfx.mouse_y

        -- Hook for user code
        if GUI.onmousemove then GUI.onmousemove() end

    else

        GUI.mouse.lx, GUI.mouse.ly = GUI.mouse.x, GUI.mouse.y

    end
    GUI.mouse.wheel = gfx.mouse_wheel
    GUI.mouse.cap = gfx.mouse_cap
    GUI.char = gfx.getchar()

    if GUI.cur_w ~= gfx.w or GUI.cur_h ~= gfx.h then
        GUI.cur_w, GUI.cur_h = gfx.w, gfx.h

        GUI.resized = true

        -- Hook for user code
        if GUI.onresize then GUI.onresize() end

    else
        GUI.resized = false
    end

    --	(Escape key)	(Window closed)		(User function says to close)
    --if GUI.char == 27 or GUI.char == -1 or GUI.quit == true then
    if (GUI.char == 27 and not (	GUI.mouse.cap & 4 == 4
                                or 	GUI.mouse.cap & 8 == 8
                                or 	GUI.mouse.cap & 16 == 16
                                or  GUI.escape_bypass))
            or GUI.char == -1
            or GUI.quit == true then

        GUI.cleartooltip()
        return 0
    else
        if GUI.char == 27 and GUI.escape_bypass then GUI.escape_bypass = "close" end
        reaper.defer(GUI.Main)
    end

end


--[[
    Update each element's state, starting from the top down.

    This is very important, so that lower elements don't
    "steal" the mouse.


    This function will also delete any elements that have their z set to -1

    Handy for something like Label:fade if you just want to remove
    the faded element entirely

    ***Don't try to remove elements in the middle of the Update
    loop; use this instead to have them automatically cleaned up***

]]--
GUI.Main_Update_Elms = function ()

    -- Disabled May 2/2018 to see if it was actually necessary
    -- GUI.update_elms_list()

    -- We'll use this to shorten each elm's update loop if the user did something
    -- Slightly more efficient, and averts any bugs from false positives
    GUI.elm_updated = false

    -- Check for the dev mode toggle before we get too excited about updating elms
    if  GUI.char == 282         and GUI.mouse.cap & 4 ~= 0
    and GUI.mouse.cap & 8 ~= 0  and GUI.mouse.cap & 16 ~= 0 then

        GUI.dev_mode = not GUI.dev_mode
        GUI.elm_updated = true
        GUI.redraw_z[0] = true

    end


    -- Mouse was moved? Clear the tooltip
    if GUI.tooltip and (GUI.mouse.x - GUI.mouse.lx > 0 or GUI.mouse.y - GUI.mouse.ly > 0) then

        GUI.mouseover_elm = nil
        GUI.cleartooltip()

    end


    -- Bypass for some skip logic to allow tabbing between elements (GUI.tab_to_next)
    if GUI.newfocus then
        GUI.newfocus.focus = true
        GUI.newfocus = nil
    end


    for i = 0, GUI.z_max do
        if  GUI.elms_list[i] and #GUI.elms_list[i] > 0
        and not (GUI.elms_hide[i] or GUI.elms_freeze[i]) then
            for __, elm in pairs(GUI.elms_list[i]) do

                if elm and GUI.elms[elm] then GUI.Update(GUI.elms[elm]) end

            end
        end

    end

    -- Just in case any user functions want to know...
    GUI.mouse.last_down = GUI.mouse.down
    GUI.mouse.last_r_down = GUI.mouse.r_down
    GUI.mouse.last_m_down = GUI.mouse.m_down

end


GUI.Main_Draw = function ()

    -- Redraw all of the elements, starting from the bottom up.
    local w, h = GUI.cur_w, GUI.cur_h

    local need_redraw, global_redraw
    if GUI.redraw_z[0] then
        global_redraw = true
        GUI.redraw_z[0] = false
    else
        for z, b in pairs(GUI.redraw_z) do
            if b == true then
                need_redraw = true
                break
            end
        end
    end

    if need_redraw or global_redraw then

        -- All of the layers will be drawn to their own buffer (dest = z), then
        -- composited in buffer 0. This allows buffer 0 to be blitted as a whole
        -- when none of the layers need to be redrawn.

        gfx.dest = 0
        gfx.setimgdim(0, -1, -1)
        gfx.setimgdim(0, w, h)

        GUI.color("wnd_bg")
        gfx.rect(0, 0, w, h, 1)

        for i = GUI.z_max, 0, -1 do
            if  GUI.elms_list[i] and #GUI.elms_list[i] > 0
            and not GUI.elms_hide[i] then

                if global_redraw or GUI.redraw_z[i] then

                    -- Set this before we redraw, so that elms can call a redraw
                    -- from their own :draw method. e.g. Labels fading out
                    GUI.redraw_z[i] = false

                    gfx.setimgdim(i, -1, -1)
                    gfx.setimgdim(i, w, h)
                    gfx.dest = i

                    for __, elm in pairs(GUI.elms_list[i]) do
                        if not GUI.elms[elm] then
                            reaper.MB(  "Error: Tried to update a GUI element that doesn't exist:"..
                                        "\nGUI.elms." .. tostring(elm), "Whoops!", 0)
                        end

                        -- Reset these just in case an element or some user code forgot to,
                        -- otherwise we get things like the whole buffer being blitted with a=0.2
                        gfx.mode = 0
                        gfx.set(0, 0, 0, 1)

                        GUI.elms[elm]:draw()
                    end

                    gfx.dest = 0
                end

                gfx.blit(i, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)
            end
        end

        -- Draw developer hints if necessary
        if GUI.dev_mode then
            GUI.Draw_Dev()
        else
            GUI.Draw_Version()
        end

    end


    -- Reset them again, to be extra sure
    gfx.mode = 0
    gfx.set(0, 0, 0, 1)

    gfx.dest = -1
    gfx.blit(0, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)

    gfx.update()

end



-- Display the GUI version number
-- Set GUI.version = 0 to hide this
GUI.Draw_Version = function ()

    if not GUI.version then return 0 end

    local str = "Lokasenna_GUI "..GUI.version

    GUI.font("version")
    GUI.color("txt")

    local str_w, str_h = gfx.measurestr(str)

    --gfx.x = GUI.w - str_w - 4
    --gfx.y = GUI.h - str_h - 4
    gfx.x = gfx.w - str_w - 6
    gfx.y = gfx.h - str_h - 4

    gfx.drawstr(str)

end




------------------------------------
-------- Buffer functions ----------
------------------------------------


--[[
    We'll use this to let elements have their own graphics buffers
    to do whatever they want in.

    num	=	How many buffers you want, or 1 if not specified.

    Returns a table of buffers, or just a buffer number if num = 1

    i.e.

    -- Assign this element's buffer
    function GUI.my_element:new(.......)

        ...new stuff...

        my_element.buffers = GUI.GetBuffer(4)
        -- or
        my_element.buffer = GUI.GetBuffer()

    end

    -- Draw to the buffer
    function GUI.my_element:init()

        gfx.dest = self.buffers[1]
        -- or
        gfx.dest = self.buffer
        ...draw stuff...

    end

    -- Copy from the buffer
    function GUI.my_element:draw()
        gfx.blit(self.buffers[1], 1, 0)
        -- or
        gfx.blit(self.buffer, 1, 0)
    end

]]--

-- Any used buffers will be marked as True here
GUI.buffers = {}

-- When deleting elements, their buffer numbers
-- will be added here for easy access.
GUI.freed_buffers = {}

GUI.GetBuffer = function (num)

    local ret = {}
    --local prev

    for i = 1, (num or 1) do

        if #GUI.freed_buffers > 0 then

            ret[i] = table.remove(GUI.freed_buffers)

        else

            for j = 1023, GUI.z_max + 1, -1 do
            --for j = (not prev and 1023 or prev - 1), 0, -1 do

                if not GUI.buffers[j] then
                    ret[i] = j

                    GUI.buffers[j] = true
                    goto skip
                end

            end

            -- Something bad happened, probably my fault
            GUI.error_message = "Couldn't get a new graphics buffer - buffer would overlap element space. z = " .. GUI.z_max

            ::skip::
        end

    end

    return (#ret == 1) and ret[1] or ret

end

-- Elements should pass their buffer (or buffer table) to this
-- when being deleted
GUI.FreeBuffer = function (num)

    if type(num) == "number" then
        table.insert(GUI.freed_buffers, num)
    else
        for k, v in pairs(num) do
            table.insert(GUI.freed_buffers, v)
        end
    end

end




------------------------------------
-------- Element functions ---------
------------------------------------


--[[
    Wrapper for creating new elements, allows them to know their own name
    If called after the script window has opened, will also run their :init
    method.
    Can be given a user class directly by passing the class itself as 'elm',
    or if 'elm' is a string will look for a class in GUI[elm]

    Elements can be created in two ways:

        ex. Label:  name, z, x, y, caption[, shadow, font, color, bg]

    1. Function arguments

                name        type
        GUI.New("my_label", "Label", 1, 16, 16, "Hello!", true, 1, "red", "white")


    2. Keyed tables

        GUI.New({
            name = "my_label",
            type = "Label",
            z = 1,
            x = 16,
            y = 16,
            caption = "Hello!",
            shadow = true,
            font = 1,
            color = "red",
            bg = "white"
        })

    The only functional difference is that, when using a keyed table, additional parameters can
    be specified beyond the basic creation parameters given for that class. When using method 1,
    any additional parameters simply have to be specified afterward via:

        GUI.elms.my_label.shadow = false

    See the class documentation for more detail.
]]--
GUI.New = function (name, elm, ...)

    -- Support for passing all of the element params as a single keyed table
    local name = name
    local elm = elm
    local params
    if not elm and type(name) == "table" then

        -- Copy the table so we can pass it on
        params = name

        -- Grab the name and type
        elm = name.type
        name = name.name

    end


    -- Support for passing element classes directly as a table
    local elm = type(elm) == "string"   and GUI[elm]
                                        or  elm

    -- If we don't have an elm at this point there's a problem
    if not elm or type(elm) ~= "table" then
        reaper.ShowMessageBox(  "Unable to create element '"..tostring(name)..
                                "'.\nClass '"..tostring(elm).."' isn't available.",
                                "GUI Error", 0)
        GUI.quit = true
        return nil
    end

    -- If we're overwriting a previous elm, make sure it frees its buffers, etc
    if GUI.elms[name] and GUI.elms[name].type then GUI.elms[name]:delete() end

    GUI.elms[name] = params and elm:new(name, params) or elm:new(name, ...)
    --GUI.elms[name] = elm:new(name, params or ...)

    if GUI.gfx_open then GUI.elms[name]:init() end

    -- Return this so (I think) a bunch of new elements could be created
    -- within a table that would end up holding their names for easy bulk
    -- processing.

    return name

end


--  Create multiple elms at once
--[[
    Pass a table of keyed tables for each element:

    local elms = {}
    elms.my_label = {
        type = "Label"
        x = 16
        ...
    }
    elms.my_button = {
        type = "Button"
        ...
    }

    GUI.CreateElms(elms)


]]--
function GUI.CreateElms(elms)

    for name, params in pairs(elms) do
        params.name = name
        GUI.New(params)
    end

end


--	See if the any of the given element's methods need to be called
GUI.Update = function (elm)

    local x, y = GUI.mouse.x, GUI.mouse.y
    local x_delta, y_delta = x-GUI.mouse.lx, y-GUI.mouse.ly
    local wheel = GUI.mouse.wheel
    local inside = GUI.IsInside(elm, x, y)

    local skip = elm:onupdate() or false

    if GUI.resized then elm:onresize() end

    if GUI.elm_updated then
        if elm.focus then
            elm.focus = false
            elm:lostfocus()
        end
        skip = true
    end


    if skip then return end

    -- Left button
    if GUI.mouse.cap&1==1 then

        -- If it wasn't down already...
        if not GUI.mouse.last_down then


            -- Was a different element clicked?
            if not inside then
                if GUI.mouse_down_elm == elm then
                    -- Should already have been reset by the mouse-up, but safeguard...
                    GUI.mouse_down_elm = nil
                end
                if elm.focus then
                    elm.focus = false
                    elm:lostfocus()
                end
                return 0
            else
                if GUI.mouse_down_elm == nil then -- Prevent click-through

                    GUI.mouse_down_elm = elm

                    -- Double clicked?
                    if GUI.mouse.downtime
                    and reaper.time_precise() - GUI.mouse.downtime < 0.10
                    then

                        GUI.mouse.downtime = nil
                        GUI.mouse.dbl_clicked = true
                        elm:ondoubleclick()

                    elseif not GUI.mouse.dbl_clicked then

                        elm.focus = true
                        elm:onmousedown()

                    end

                    GUI.elm_updated = true
                end

                GUI.mouse.down = true
                GUI.mouse.ox, GUI.mouse.oy = x, y

                -- Where in the elm the mouse was clicked. For dragging stuff
                -- and keeping it in the place relative to the cursor.
                GUI.mouse.off_x, GUI.mouse.off_y = x - elm.x, y - elm.y

            end

        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0)
        and     GUI.mouse_down_elm == elm then

            if elm.focus ~= false then

                GUI.elm_updated = true
                elm:ondrag(x_delta, y_delta)

            end
        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.down and GUI.mouse_down_elm.name == elm.name then

            GUI.mouse_down_elm = nil

            if not GUI.mouse.dbl_clicked then elm:onmouseup() end

            GUI.elm_updated = true
            GUI.mouse.down = false
            GUI.mouse.dbl_clicked = false
            GUI.mouse.ox, GUI.mouse.oy = -1, -1
            GUI.mouse.off_x, GUI.mouse.off_y = -1, -1
            GUI.mouse.lx, GUI.mouse.ly = -1, -1
            GUI.mouse.downtime = reaper.time_precise()


    end


    -- Right button
    if GUI.mouse.cap&2==2 then

        -- If it wasn't down already...
        if not GUI.mouse.last_r_down then

            -- Was a different element clicked?
            if not inside then
                if GUI.rmouse_down_elm == elm then
                    -- Should have been reset by the mouse-up, but in case...
                    GUI.rmouse_down_elm = nil
                end
                --elm.focus = false
            else

                -- Prevent click-through
                if GUI.rmouse_down_elm == nil then

                    GUI.rmouse_down_elm = elm

                        -- Double clicked?
                    if GUI.mouse.r_downtime
                    and reaper.time_precise() - GUI.mouse.r_downtime < 0.20
                    then

                        GUI.mouse.r_downtime = nil
                        GUI.mouse.r_dbl_clicked = true
                        elm:onr_doubleclick()

                    elseif not GUI.mouse.r_dbl_clicked then

                        elm:onmouser_down()

                    end

                    GUI.elm_updated = true

                end

                GUI.mouse.r_down = true
                GUI.mouse.r_ox, GUI.mouse.r_oy = x, y
                -- Where in the elm the mouse was clicked. For dragging stuff
                -- and keeping it in the place relative to the cursor.
                GUI.mouse.r_off_x, GUI.mouse.r_off_y = x - elm.x, y - elm.y

            end


        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0)
        and     GUI.rmouse_down_elm == elm then

            if elm.focus ~= false then

                elm:onr_drag(x_delta, y_delta)
                GUI.elm_updated = true

            end

        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.r_down and GUI.rmouse_down_elm.name == elm.name then

        GUI.rmouse_down_elm = nil

        if not GUI.mouse.r_dbl_clicked then elm:onmouser_up() end

        GUI.elm_updated = true
        GUI.mouse.r_down = false
        GUI.mouse.r_dbl_clicked = false
        GUI.mouse.r_ox, GUI.mouse.r_oy = -1, -1
        GUI.mouse.r_off_x, GUI.mouse.r_off_y = -1, -1
        GUI.mouse.r_lx, GUI.mouse.r_ly = -1, -1
        GUI.mouse.r_downtime = reaper.time_precise()

    end



    -- Middle button
    if GUI.mouse.cap&64==64 then


        -- If it wasn't down already...
        if not GUI.mouse.last_m_down then


            -- Was a different element clicked?
            if not inside then
                if GUI.mmouse_down_elm == elm then
                    -- Should have been reset by the mouse-up, but in case...
                    GUI.mmouse_down_elm = nil
                end
            else
                -- Prevent click-through
                if GUI.mmouse_down_elm == nil then

                    GUI.mmouse_down_elm = elm

                    -- Double clicked?
                    if GUI.mouse.m_downtime
                    and reaper.time_precise() - GUI.mouse.m_downtime < 0.20
                    then

                        GUI.mouse.m_downtime = nil
                        GUI.mouse.m_dbl_clicked = true
                        elm:onm_doubleclick()

                    else

                        elm:onmousem_down()

                    end

                    GUI.elm_updated = true

              end

                GUI.mouse.m_down = true
                GUI.mouse.m_ox, GUI.mouse.m_oy = x, y
                GUI.mouse.m_off_x, GUI.mouse.m_off_y = x - elm.x, y - elm.y

            end



        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0)
        and     GUI.mmouse_down_elm == elm then

            if elm.focus ~= false then

                elm:onm_drag(x_delta, y_delta)
                GUI.elm_updated = true

            end

        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.m_down and GUI.mmouse_down_elm.name == elm.name then

        GUI.mmouse_down_elm = nil

        if not GUI.mouse.m_dbl_clicked then elm:onmousem_up() end

        GUI.elm_updated = true
        GUI.mouse.m_down = false
        GUI.mouse.m_dbl_clicked = false
        GUI.mouse.m_ox, GUI.mouse.m_oy = -1, -1
        GUI.mouse.m_off_x, GUI.mouse.m_off_y = -1, -1
        GUI.mouse.m_lx, GUI.mouse.m_ly = -1, -1
        GUI.mouse.m_downtime = reaper.time_precise()

    end



    -- If the mouse is hovering over the element
    if inside and not GUI.mouse.down and not GUI.mouse.r_down then
        elm:onmouseover()

        -- Initial mouseover an element
        if GUI.mouseover_elm ~= elm then
            GUI.mouseover_elm = elm
            GUI.mouseover_time = reaper.time_precise()

        -- Mouse was moved; reset the timer
        elseif x_delta > 0 or y_delta > 0 then

            GUI.mouseover_time = reaper.time_precise()

        -- Display a tooltip
        elseif (reaper.time_precise() - GUI.mouseover_time) >= GUI.tooltip_time then

            GUI.settooltip(elm.tooltip)

        end
        --elm.mouseover = true
    else
        --elm.mouseover = false

    end


    -- If the mousewheel's state has changed
    if inside and GUI.mouse.wheel ~= GUI.mouse.lwheel then

        GUI.mouse.inc = (GUI.mouse.wheel - GUI.mouse.lwheel) / 120

        elm:onwheel(GUI.mouse.inc)
        GUI.elm_updated = true
        GUI.mouse.lwheel = GUI.mouse.wheel

    end

    -- If the element is in focus and the user typed something
    if elm.focus and GUI.char ~= 0 then
        elm:ontype()
        GUI.elm_updated = true
    end

end


--[[	Return or change an element's value

    For use with external user functions. Returns the given element's current
    value or, if specified, sets a new one.	Changing values with this is often
    preferable to setting them directly, as most :val methods will also update
    some internal parameters and redraw the element when called.
]]--
GUI.Val = function (elm, newval)

    if not GUI.elms[elm] then return nil end

    if newval ~= nil then
        GUI.elms[elm]:val(newval)
    else
        return GUI.elms[elm]:val()
    end

end


-- Are these coordinates inside the given element?
-- If no coords are given, will use the mouse cursor
GUI.IsInside = function (elm, x, y)

    if not elm then return false end

    local x, y = x or GUI.mouse.x, y or GUI.mouse.y

    return	(	x >= (elm.x or 0) and x < ((elm.x or 0) + (elm.w or 0)) and
                y >= (elm.y or 0) and y < ((elm.y or 0) + (elm.h or 0))	)

end


-- Returns the x,y that would center elm1 within elm2.
-- Axis can be "x", "y", or "xy".
GUI.center = function (elm1, elm2)

    local elm2 = elm2   and elm2
                        or  {x = 0, y = 0, w = GUI.cur_w, h = GUI.cur_h}

    if not (    elm2.x and elm2.y and elm2.w and elm2.h
            and elm1.x and elm1.y and elm1.w and elm1.h) then return end

    return (elm2.x + (elm2.w - elm1.w) / 2), (elm2.y + (elm2.h - elm1.h) / 2)


end




------------------------------------
-------- Prototype element ---------
----- + all default methods --------
------------------------------------


--[[
    All classes will use this as their template, so that
    elements are initialized with every method available.
]]--
GUI.Element = {}
function GUI.Element:new(name)

    local elm = {}
    if name then elm.name = name end
    self.z = 1

    setmetatable(elm, self)
    self.__index = self
    return elm

end

-- Called a) when the script window is first opened
-- 		  b) when any element is created via GUI.New after that
-- i.e. Elements can draw themselves to a buffer once on :init()
-- and then just blit/rotate/etc as needed afterward
function GUI.Element:init() end

-- Called whenever the element's z layer is told to redraw
function GUI.Element:draw() end

-- Ask for a redraw on the next update
function GUI.Element:redraw()
    GUI.redraw_z[self.z] = true
end

-- Called on every update loop, unless the element is hidden or frozen
function GUI.Element:onupdate() end

function GUI.Element:delete()

    self.ondelete(self)
    GUI.elms[self.name] = nil

end

-- Called when the element is deleted by GUI.update_elms_list() or :delete.
-- Use it for freeing up buffers and anything else memorywise that this
-- element was doing
function GUI.Element:ondelete() end


-- Set or return the element's value
-- Can be useful for something like a Slider that doesn't have the same
-- value internally as what it's displaying
function GUI.Element:val() end

-- Called when an element's value has changed
function GUI.Element:onchange() end

-- Called on every update loop if the mouse is over this element.
function GUI.Element:onmouseover() end

-- Only called once; won't repeat if the button is held
function GUI.Element:onmousedown() end

function GUI.Element:onmouseup() end
function GUI.Element:ondoubleclick() end

-- Will continue being called even if you drag outside the element
function GUI.Element:ondrag() end

-- Right-click
function GUI.Element:onmouser_down() end
function GUI.Element:onmouser_up() end
function GUI.Element:onr_doubleclick() end
function GUI.Element:onr_drag() end

-- Middle-click
function GUI.Element:onmousem_down() end
function GUI.Element:onmousem_up() end
function GUI.Element:onm_doubleclick() end
function GUI.Element:onm_drag() end

function GUI.Element:onwheel() end
function GUI.Element:ontype() end


-- Elements like a Textbox that need to keep track of their focus
-- state will use this to e.g. update the text somewhere else
-- when the user clicks out of the box.
function GUI.Element:lostfocus() end

-- Called when the script window has been resized
function GUI.Element:onresize() end


------------------------------------
-------- Developer stuff -----------
------------------------------------


-- Print a string to the Reaper console.
GUI.Msg = function (str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

-- Returns the specified parameters for a given element.
-- If nothing is specified, returns all of the element's properties.
-- ex. local str = GUI.elms.my_element:Msg("x", "y", "caption", "col_txt")
function GUI.Element:Msg(...)

    local arg = {...}

    if #arg == 0 then
        arg = {}
        for k in GUI.kpairs(self, "full") do
            arg[#arg+1] = k
        end
    end

    if not self or not self.type then return end
    local pre = tostring(self.name) .. "."
    local strs = {}

    for i = 1, #arg do

        strs[#strs + 1] = pre .. tostring(arg[i]) .. " = "

        if type(self[arg[i]]) == "table" then
            strs[#strs] = strs[#strs] .. "table:"
            strs[#strs + 1] = GUI.table_list(self[arg[i]], nil, 1)
        else
            strs[#strs] = strs[#strs] .. tostring(self[arg[i]])
        end

    end

    --reaper.ShowConsoleMsg( "\n" .. table.concat(strs, "\n") .. "\n")
    return table.concat(strs, "\n")

end


-- Developer mode settings
GUI.dev = {

    -- grid_a must be a multiple of grid_b, or it will
    -- probably never be drawn
    grid_a = 128,
    grid_b = 16

}


-- Draws a grid overlay and some developer hints
-- Toggled via Ctrl+Shift+Alt+Z, or by setting GUI.dev_mode = true
GUI.Draw_Dev = function ()

    -- Draw a grid for placing elements
    GUI.color("magenta")
    gfx.setfont("Courier New", 10)

    for i = 0, GUI.w, GUI.dev.grid_b do

        local a = (i == 0) or (i % GUI.dev.grid_a == 0)
        gfx.a = a and 1 or 0.3
        gfx.line(i, 0, i, GUI.h)
        gfx.line(0, i, GUI.w, i)
        if a then
            gfx.x, gfx.y = i + 4, 4
            gfx.drawstr(i)
            gfx.x, gfx.y = 4, i + 4
            gfx.drawstr(i)
        end

    end

    local str = "Mouse: "..math.modf(GUI.mouse.x)..", "..math.modf(GUI.mouse.y).." "
    local str_w, str_h = gfx.measurestr(str)
    gfx.x, gfx.y = GUI.w - str_w - 2, GUI.h - 2*str_h - 2

    GUI.color("black")
    gfx.rect(gfx.x - 2, gfx.y - 2, str_w + 4, 2*str_h + 4, true)

    GUI.color("white")
    gfx.drawstr(str)

    local snap_x, snap_y = GUI.nearestmultiple(GUI.mouse.x, GUI.dev.grid_b),
                            GUI.nearestmultiple(GUI.mouse.y, GUI.dev.grid_b)

    gfx.x, gfx.y = GUI.w - str_w - 2, GUI.h - str_h - 2
    gfx.drawstr(" Snap: "..snap_x..", "..snap_y)

    gfx.a = 1

    GUI.redraw_z[0] = true

end




------------------------------------
-------- Constants/presets ---------
------------------------------------


GUI.chars = {

    ESCAPE		= 27,
    SPACE		= 32,
    BACKSPACE	= 8,
    TAB			= 9,
    HOME		= 1752132965,
    END			= 6647396,
    INSERT		= 6909555,
    DELETE		= 6579564,
    PGUP		= 1885828464,
    PGDN		= 1885824110,
    RETURN		= 13,
    UP			= 30064,
    DOWN		= 1685026670,
    LEFT		= 1818584692,
    RIGHT		= 1919379572,

    F1			= 26161,
    F2			= 26162,
    F3			= 26163,
    F4			= 26164,
    F5			= 26165,
    F6			= 26166,
    F7			= 26167,
    F8			= 26168,
    F9			= 26169,
    F10			= 6697264,
    F11			= 6697265,
    F12			= 6697266

}


--[[	Font and color presets

    Can be set using the accompanying functions GUI.font
    and GUI.color. i.e.

    GUI.font(2)				applies the Header preset
    GUI.color("elm_fill")	applies the Element Fill color preset

    Colors are converted from 0-255 to 0-1 when GUI.Init() runs,
    so if you need to access the values directly at any point be
    aware of which format you're getting in return.

]]--

GUI.OS_fonts = {

    Windows = {
        sans = "Calibri",
        mono = "Lucida Console"
    },

    OSX = {
        sans = "Helvetica Neue",
        mono = "Andale Mono"
    },

    Linux = {
        sans = "Arial",
        mono = "DejaVuSansMono"
    }

}

GUI.get_OS_fonts = function()

    local os = reaper.GetOS()
    if os:match("Win") then
        return GUI.OS_fonts.Windows
    elseif os:match("OSX") or os:match("macOS") then
        return GUI.OS_fonts.OSX
    else
        return GUI.OS_fonts.Linux
    end

end

local fonts = GUI.get_OS_fonts()
GUI.fonts = {

                -- Font, size, bold/italics/underline
                -- 				^ One string: "b", "iu", etc.
                {fonts.sans, 32},	-- 1. Title
                {fonts.sans, 20},	-- 2. Header
                {fonts.sans, 16},	-- 3. Label
                {fonts.sans, 16},	-- 4. Value
    monospace = {fonts.mono, 14},
    version = 	{fonts.sans, 12, "i"},

}



GUI.colors = {

    -- Element colors
    wnd_bg = {64, 64, 64, 255},			-- Window BG
    tab_bg = {56, 56, 56, 255},			-- Tabs BG
    elm_bg = {48, 48, 48, 255},			-- Element BG
    elm_frame = {96, 96, 96, 255},		-- Element Frame
    elm_fill = {64, 192, 64, 255},		-- Element Fill
    elm_outline = {32, 32, 32, 255},	-- Element Outline
    txt = {192, 192, 192, 255},			-- Text

    shadow = {0, 0, 0, 48},				-- Element Shadows
    faded = {0, 0, 0, 64},

    -- Standard 16 colors
    black = {0, 0, 0, 255},
    white = {255, 255, 255, 255},
    red = {255, 0, 0, 255},
    lime = {0, 255, 0, 255},
    blue =  {0, 0, 255, 255},
    yellow = {255, 255, 0, 255},
    cyan = {0, 255, 255, 255},
    magenta = {255, 0, 255, 255},
    silver = {192, 192, 192, 255},
    gray = {128, 128, 128, 255},
    maroon = {128, 0, 0, 255},
    olive = {128, 128, 0, 255},
    green = {0, 128, 0, 255},
    purple = {128, 0, 128, 255},
    teal = {0, 128, 128, 255},
    navy = {0, 0, 128, 255},

    none = {0, 0, 0, 0},


}


-- Global shadow size, in pixels
GUI.shadow_dist = 2


--[[
    How fast the caret in textboxes should blink, measured in GUI update loops.

    '16' looks like a fairly typical textbox caret.

    Because each On and Off redraws the textbox's Z layer, this can cause CPU
    issues in scripts with lots of drawing to do. In that case, raising it to
    24 or 32 will still look alright but require less redrawing.
]]--
GUI.txt_blink_rate = 16


-- Odds are you don't need too much precision here
-- If you do, just specify GUI.pi = math.pi() in your code
GUI.pi = 3.14159


-- Delay time when hovering over an element before displaying a tooltip
GUI.tooltip_time = 0.8


------------------------------------
-------- Table functions -----------
------------------------------------


--[[	Copy the contents of one table to another, since Lua can't do it natively

    Provide a second table as 'base' to use it as the basis for copying, only
    bringing over keys from the source table that don't exist in the base

    'depth' only exists to provide indenting for my debug messages, it can
    be left out when calling the function.
]]--
GUI.table_copy = function (source, base, depth)

    -- 'Depth' is only for indenting debug messages
    depth = ((not not depth) and (depth + 1)) or 0



    if type(source) ~= "table" then return source end

    local meta = getmetatable(source)
    local new = base or {}
    for k, v in pairs(source) do



        if type(v) == "table" then

            if base then
                new[k] = GUI.table_copy(v, base[k], depth)
            else
                new[k] = GUI.table_copy(v, nil, depth)
            end

        else
            if not base or (base and new[k] == nil) then

                new[k] = v
            end
        end

    end
    setmetatable(new, meta)

    return new

end


-- (For debugging)
-- Returns a string of the table's contents, indented to show nested tables
-- If 't' contains classes, or a lot of nested tables, etc, be wary of using larger
-- values for max_depth - this function will happily freeze Reaper for ten minutes.
GUI.table_list = function (t, max_depth, cur_depth)

    local ret = {}
    local n,v
    cur_depth = cur_depth or 0

    for n,v in pairs(t) do

                ret[#ret+1] = string.rep("\t", cur_depth) .. n .. " = "

                if type(v) == "table" then

                    ret[#ret] = ret[#ret] .. "table:"
                    if not max_depth or cur_depth <= max_depth then
                        ret[#ret+1] = GUI.table_list(v, max_depth, cur_depth + 1)
                    end

                else

                    ret[#ret] = ret[#ret] .. tostring(v)
                end

    end

    return table.concat(ret, "\n")

end


-- Compare the contents of one table to another, since Lua can't do it natively
-- Returns true if all of t_a's keys + and values match all of t_b's.
GUI.table_compare = function (t_a, t_b)

    if type(t_a) ~= "table" or type(t_b) ~= "table" then return false end

    local key_exists = {}
    for k1, v1 in pairs(t_a) do
        local v2 = t_b[k1]
        if v2 == nil or not GUI.table_compare(v1, v2) then return false end
        key_exists[k1] = true
    end
    for k2, v2 in pairs(t_b) do
        if not key_exists[k2] then return false end
    end

    return true

end


-- 	Sorting function adapted from: http://lua-users.org/wiki/SortedIteration
GUI.full_sort = function (op1, op2)

    -- Sort strings that begin with a number as if they were numbers,
    -- i.e. so that 12 > "6 apples"
    if type(op1) == "string" and string.match(op1, "^(%-?%d+)") then
        op1 = tonumber( string.match(op1, "^(%-?%d+)") )
    end
    if type(op2) == "string" and string.match(op2, "^(%-?%d+)") then
        op2 = tonumber( string.match(op2, "^(%-?%d+)") )
    end

    --if op1 == "0" then op1 = 0 end
    --if op2 == "0" then op2 = 0 end
    local type1, type2 = type(op1), type(op2)
    if type1 ~= type2 then --cmp by type
        return type1 < type2
    elseif type1 == "number" and type2 == "number"
        or type1 == "string" and type2 == "string" then
        return op1 < op2 --comp by default
    elseif type1 == "boolean" and type2 == "boolean" then
        return op1 == true
    else
        return tostring(op1) < tostring(op2) --cmp by address
    end

end


--[[	Allows "for x, y in pairs(z) do" in alphabetical/numerical order

    Copied from Programming In Lua, 19.3

    Call with f = "full" to use the full sorting function above, or
    use f to provide your own sorting function as per pairs() and ipairs()

]]--
GUI.kpairs = function (t, f)


    if f == "full" then
        f = GUI.full_sort
    end

    local a = {}
    for n in pairs(t) do table.insert(a, n) end

    table.sort(a, f)

    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function

        i = i + 1

        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end

    end


    return iter
end


-- Accepts a table, and returns a table with the keys and values swapped, i.e.
-- {a = 1, b = 2, c = 3} --> {1 = "a", 2 = "b", 3 = "c"}
GUI.table_invert = function(t)

    local tmp = {}

    for k, v in pairs(t) do
        tmp[v] = k
    end

    return tmp

end


-- Looks through a table using ipairs (specify a different function with 'f') and returns
-- the first key whose value matches 'find'. 'find' is checked using string.match, so patterns
-- should be allowable. No (captures) though.

-- If you need to find multiple values in the same table, and each of them only occurs once,
-- it will be more efficient to just copy the table with GUI.table_invert and check by key.
GUI.table_find = function(t, find, f)
    local iter = f or ipairs

    for k, v in iter(t) do
        if string.match(tostring(v), find) then return k end
    end

end


-- Returns the length of a table, counting both indexed and keyed elements
GUI.table_length = function(t)

    local len = 0
    for k in pairs(t) do
        len = len + 1
    end

    return len

end
------------------------------------
-------- Text functions ------------
------------------------------------


--[[	Apply a font preset

    fnt			Font preset number
                or
                A preset table -> GUI.font({"Arial", 10, "i"})

]]--
GUI.font = function (fnt)
    local font, size, str = table.unpack( type(fnt) == "table"
                                            and fnt
                                            or  GUI.fonts[fnt])

    -- Different OSes use different font sizes, for some reason
    -- This should give a similar size on Mac/Linux as on Windows
    if not string.match( reaper.GetOS(), "Win") then
        size = math.floor(size * 0.77)
    end

    -- Cheers to Justin and Schwa for this
    local flags = 0
    if str then
        for i = 1, str:len() do
            flags = flags * 256 + string.byte(str, i)
        end
    end

    gfx.setfont(1, font, size, flags)

end


--[[	Prepares a table of character widths

    Iterates through all of the GUI.fonts[] presets, storing the widths
    of every printable ASCII character in a table.

    Accessable via:		GUI.txt_width[font_num][char_num]

    - Requires a window to have been opened in Reaper

    - 'get_txt_width' and 'word_wrap' will automatically run this
      if it hasn't been run already; it may be rather clunky to use
      on demand depending on what your script is doing, so it's
      probably better to run this immediately after initiliazing
      the window and then have the width table ready to use.
]]--

GUI.init_txt_width = function ()

    GUI.txt_width = {}
    local arr
    for k in pairs(GUI.fonts) do

        GUI.font(k)
        GUI.txt_width[k] = {}
        arr = {}

        for i = 1, 255 do

            arr[i] = gfx.measurechar(i)

        end

        GUI.txt_width[k] = arr

    end

end


-- Returns the total width (in pixels) for a given string and font
-- (as a GUI.fonts[] preset number or name)
-- Most of the time it's simpler to use gfx.measurestr(), but scripts
-- with a lot of text should use this instead - it's 10-12x faster.
GUI.get_txt_width = function (str, font)

    if not GUI.txt_width then GUI.init_txt_width() end

    local widths = GUI.txt_width[font]
    local w = 0
    for i = 1, string.len(str) do

        w = w + widths[		string.byte(	string.sub(str, i, i)	) ]

    end

    return w

end


-- Measures a string to see how much of it will it in the given width,
-- then returns both the trimmed string and the excess
GUI.fit_txt_width = function (str, font, w)

    local len = string.len(str)

    -- Assuming 'i' is the narrowest character, get an upper limit
    local max_end = math.floor( w / GUI.txt_width[font][string.byte("i")] )

    for i = max_end, 1, -1 do

        if GUI.get_txt_width( string.sub(str, 1, i), font ) < w then

            return string.sub(str, 1, i), string.sub(str, i + 1)

        end

    end

    -- Worst case: not even one character will fit
    -- If this actually happens you should probably rethink your choices in life.
    return "", str

end


--[[	Returns 'str' wrapped to fit a given pixel width

    str		String. Can include line breaks/paragraphs; they should be preserved.
    font	Font preset number
    w		Pixel width
    indent	Number of spaces to indent the first line of each paragraph
            (The algorithm skips tab characters and leading spaces, so
            use this parameter instead)

    i.e.	Blah blah blah blah		-> indent = 2 ->	  Blah blah blah blah
            blah blah blah blah							blah blah blah blah


    pad		Indent wrapped lines by the first __ characters of the paragraph
            (For use with bullet points, etc)

    i.e.	- Blah blah blah blah	-> pad = 2 ->	- Blah blah blah blah
            blah blah blah blah				  	 	  blah blah blah blah


    This function expands on the "greedy" algorithm found here:
    https://en.wikipedia.org/wiki/Line_wrap_and_word_wrap#Algorithm

]]--
GUI.word_wrap = function (str, font, w, indent, pad)

    if not GUI.txt_width then GUI.init_txt_width() end

    local ret_str = {}

    local w_left, w_word
    local space = GUI.txt_width[font][string.byte(" ")]

    local new_para = indent and string.rep(" ", indent) or 0

    local w_pad = pad   and GUI.get_txt_width( string.sub(str, 1, pad), font )
                        or 0
    local new_line = "\n"..string.rep(" ", math.floor(w_pad / space)	)


    for line in string.gmatch(str, "([^\n\r]*)[\n\r]*") do

        table.insert(ret_str, new_para)

        -- Check for leading spaces and tabs
        local leading, line = string.match(line, "^([%s\t]*)(.*)$")
        if leading then table.insert(ret_str, leading) end

        w_left = w
        for word in string.gmatch(line,  "([^%s]+)") do

            w_word = GUI.get_txt_width(word, font)
            if (w_word + space) > w_left then

                table.insert(ret_str, new_line)
                w_left = w - w_word

            else

                w_left = w_left - (w_word + space)

            end

            table.insert(ret_str, word)
            table.insert(ret_str, " ")

        end

        table.insert(ret_str, "\n")

    end

    table.remove(ret_str, #ret_str)
    ret_str = table.concat(ret_str)

    return ret_str

end


-- Draw the given string of the first color with a shadow
-- of the second color (at 45' to the bottom-right)
GUI.shadow = function (str, col1, col2)

    local x, y = gfx.x, gfx.y

    GUI.color(col2 or "shadow")
    for i = 1, GUI.shadow_dist do
        gfx.x, gfx.y = x + i, y + i
        gfx.drawstr(str)
    end

    GUI.color(col1)
    gfx.x, gfx.y = x, y
    gfx.drawstr(str)

end


-- Draws a string using the given text and outline color presets
GUI.outline = function (str, col1, col2)

    local x, y = gfx.x, gfx.y

    GUI.color(col2)

    gfx.x, gfx.y = x + 1, y + 1
    gfx.drawstr(str)
    gfx.x, gfx.y = x - 1, y + 1
    gfx.drawstr(str)
    gfx.x, gfx.y = x - 1, y - 1
    gfx.drawstr(str)
    gfx.x, gfx.y = x + 1, y - 1
    gfx.drawstr(str)

    GUI.color(col1)
    gfx.x, gfx.y = x, y
    gfx.drawstr(str)

end


--[[	Draw a background rectangle for the given string

    A solid background is necessary for blitting z layers
    on their own; antialiased text with a transparent background
    looks like complete shit. This function draws a rectangle 2px
    larger than your text on all sides.

    Call with your position, font, and color already set:

    gfx.x, gfx.y = self.x, self.y
    GUI.font(self.font)
    GUI.color(self.col)

    GUI.text_bg(self.text)

    gfx.drawstr(self.text)

    Also accepts an optional background color:
    GUI.text_bg(self.text, "elm_bg")

]]--
GUI.text_bg = function (str, col, align)

    local x, y = gfx.x, gfx.y
    local r, g, b, a = gfx.r, gfx.g, gfx.b, gfx.a

    col = col or "wnd_bg"

    GUI.color(col)

    local w, h = gfx.measurestr(str)
    w, h = w + 4, h + 4

    if align then

      if align & 1 == 1 then
        gfx.x = gfx.x - w/2
      elseif align & 4 == 4 then
        gfx.y = gfx.y - h/2
      end

    end

    gfx.rect(gfx.x - 2, gfx.y - 2, w, h, true)

    gfx.x, gfx.y = x, y

    gfx.set(r, g, b, a)

end




------------------------------------
-------- Color functions -----------
------------------------------------


--[[	Apply a color preset

    col			Color preset string -> "elm_fill"
                or
                Color table -> {1, 0.5, 0.5[, 1]}
                                R  G    B  [  A]
]]--
GUI.color = function (col)

    -- If we're given a table of color values, just pass it right along
    if type(col) == "table" then

        gfx.set(col[1], col[2], col[3], col[4] or 1)
    else
        gfx.set(table.unpack(GUI.colors[col]))
    end

end


-- Convert a hex color RRGGBB to 8-bit values R, G, B
GUI.hex2rgb = function (num)

    if string.sub(num, 1, 2) == "0x" then
        num = string.sub(num, 3)
    end

    local red = string.sub(num, 1, 2)
    local green = string.sub(num, 3, 4)
    local blue = string.sub(num, 5, 6)


    red = tonumber(red, 16) or 0
    green = tonumber(green, 16) or 0
    blue = tonumber(blue, 16) or 0

    return red, green, blue

end


-- Convert rgb[a] to hsv[a]; useful for gradients
-- Arguments/returns are given as 0-1
GUI.rgb2hsv = function (r, g, b, a)

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local chroma = max - min

    -- Dividing by zero is never a good idea
    if chroma == 0 then
        return 0, 0, max, (a or 1)
    end

    local hue
    if max == r then
        hue = ((g - b) / chroma) % 6
    elseif max == g then
        hue = ((b - r) / chroma) + 2
    elseif max == b then
        hue = ((r - g) / chroma) + 4
    else
        hue = -1
    end

    if hue ~= -1 then hue = hue / 6 end

    local sat = (max ~= 0) 	and	((max - min) / max)
                            or	0

    return hue, sat, max, (a or 1)


end


-- ...and back the other way
GUI.hsv2rgb = function (h, s, v, a)

    local chroma = v * s

    local hp = h * 6
    local x = chroma * (1 - math.abs(hp % 2 - 1))

    local r, g, b
    if hp <= 1 then
        r, g, b = chroma, x, 0
    elseif hp <= 2 then
        r, g, b = x, chroma, 0
    elseif hp <= 3 then
        r, g, b = 0, chroma, x
    elseif hp <= 4 then
        r, g, b = 0, x, chroma
    elseif hp <= 5 then
        r, g, b = x, 0, chroma
    elseif hp <= 6 then
        r, g, b = chroma, 0, x
    else
        r, g, b = 0, 0, 0
    end

    local min = v - chroma

    return r + min, g + min, b + min, (a or 1)

end


--[[
    Returns the color for a given position on an HSV gradient
    between two color presets

    col_a		Tables of {R, G, B[, A]}, values from 0-1
    col_b

    pos			Position along the gradient, 0 = col_a, 1 = col_b

    returns		r, g, b, a

]]--
GUI.gradient = function (col_a, col_b, pos)

    local col_a = {GUI.rgb2hsv( table.unpack( type(col_a) == "table"
                                                and col_a
                                                or  GUI.colors(col_a) )) }
    local col_b = {GUI.rgb2hsv( table.unpack( type(col_b) == "table"
                                                and col_b
                                                or  GUI.colors(col_b) )) }

    local h = math.abs(col_a[1] + (pos * (col_b[1] - col_a[1])))
    local s = math.abs(col_a[2] + (pos * (col_b[2] - col_a[2])))
    local v = math.abs(col_a[3] + (pos * (col_b[3] - col_a[3])))

    local a = (#col_a == 4)
        and  (math.abs(col_a[4] + (pos * (col_b[4] - col_a[4]))))
        or  1

    return GUI.hsv2rgb(h, s, v, a)

end




------------------------------------
-------- Math/trig functions -------
------------------------------------


-- Round a number to the nearest integer (or optional decimal places)
GUI.round = function (num, places)

    if not places then
        return num > 0 and math.floor(num + 0.5) or math.ceil(num - 0.5)
    else
        places = 10^places
        return num > 0 and math.floor(num * places + 0.5)
                        or math.ceil(num * places - 0.5) / places
    end

end


-- Returns 'val', rounded to the nearest multiple of 'snap'
GUI.nearestmultiple = function (val, snap)

    local int, frac = math.modf(val / snap)
    return (math.floor( frac + 0.5 ) == 1 and int + 1 or int) * snap

end



-- Make sure num is between min and max
-- I think it will return the correct value regardless of what
-- order you provide the values in.
GUI.clamp = function (num, min, max)

    if min > max then min, max = max, min end
    return math.min(math.max(num, min), max)

end


-- Returns an ordinal string (i.e. 30 --> 30th)
GUI.ordinal = function (num)

    rem = num % 10
    num = GUI.round(num)
    if num == 1 then
        str = num.."st"
    elseif rem == 2 then
        str = num.."nd"
    elseif num == 13 then
        str = num.."th"
    elseif rem == 3 then
        str = num.."rd"
    else
        str = num.."th"
    end

    return str

end


--[[
    Takes an angle in radians (omit Pi) and a radius, returns x, y
    Will return coordinates relative to an origin of (0,0), or absolute
    coordinates if an origin point is specified
]]--
GUI.polar2cart = function (angle, radius, ox, oy)

    local angle = angle * GUI.pi
    local x = radius * math.cos(angle)
    local y = radius * math.sin(angle)


    if ox and oy then x, y = x + ox, y + oy end

    return x, y

end


--[[
    Takes cartesian coords, with optional origin coords, and returns
    an angle (in radians) and radius. The angle is given without reference
    to Pi; that is, pi/4 rads would return as simply 0.25
]]--
GUI.cart2polar = function (x, y, ox, oy)

    local dx, dy = x - (ox or 0), y - (oy or 0)

    local angle = math.atan(dy, dx) / GUI.pi
    local r = math.sqrt(dx * dx + dy * dy)

    return angle, r

end




------------------------------------
-------- Drawing functions ---------
------------------------------------


-- Improved roundrect() function with fill, adapted from mwe's EEL example.
GUI.roundrect = function (x, y, w, h, r, antialias, fill)

    local aa = antialias or 1
    fill = fill or 0

    if fill == 0 or false then
        gfx.roundrect(x, y, w, h, r, aa)
    else

        if h >= 2 * r then

            -- Corners
            gfx.circle(x + r, y + r, r, 1, aa)			-- top-left
            gfx.circle(x + w - r, y + r, r, 1, aa)		-- top-right
            gfx.circle(x + w - r, y + h - r, r , 1, aa)	-- bottom-right
            gfx.circle(x + r, y + h - r, r, 1, aa)		-- bottom-left

            -- Ends
            gfx.rect(x, y + r, r, h - r * 2)
            gfx.rect(x + w - r, y + r, r + 1, h - r * 2)

            -- Body + sides
            gfx.rect(x + r, y, w - r * 2, h + 1)

        else

            r = (h / 2 - 1)

            -- Ends
            gfx.circle(x + r, y + r, r, 1, aa)
            gfx.circle(x + w - r, y + r, r, 1, aa)

            -- Body
            gfx.rect(x + r, y, w - (r * 2), h)

        end

    end

end


-- Improved triangle() function with optional non-fill
GUI.triangle = function (fill, ...)

    -- Pass any calls for a filled triangle on to the original function
    if fill then

        gfx.triangle(...)

    else

        -- Store all of the provided coordinates into an array
        local coords = {...}

        -- Duplicate the first pair at the end, so the last line will
        -- be drawn back to the starting point.
        table.insert(coords, coords[1])
        table.insert(coords, coords[2])

        -- Draw a line from each pair of coords to the next pair.
        for i = 1, #coords - 2, 2 do

            gfx.line(coords[i], coords[i+1], coords[i+2], coords[i+3])

        end

    end

end


--[[
    Draws run-length encoded image data

    pixels  Table of { {L, R, G, B, A, L, R, G, B, A, ...}, ... },
            one subtable per horizontal row, where L is the
            number of pixels in each run of R, G, B, A

    off_x   Optional x-offset
    off_y   Optional y-offset
]]--
GUI.draw_rle_image = function (pixels, off_x, off_y)

    off_x = off_x or 0
    off_y = off_y or 0

    for i = 1, #pixels do
        local row = pixels[i]
        local x = 0
        local y = i - 1

        for j = 1, #row, 5 do
            local length = row[j]

            gfx.set(row[j + 1] / 255, row[j + 2] / 255, row[j + 3] / 255, row[j + 4] / 255)
            gfx.rect(x + off_x, y + off_y, length, 1, true)

            x = x + length
        end
    end

end




------------------------------------
-------- File/Storage functions ----
------------------------------------


-- DEPRECATED: All operating systems seem to be fine with "/"
-- Use when working with file paths if you need to add your own /s
--    (Borrowed from X-Raym)
GUI.file_sep = string.match(reaper.GetOS(), "Win") and "\\" or "/"


-- To open files in their default app, or URLs in a browser
-- Using os.execute because reaper.ExecProcess behaves weird
-- occasionally stops working entirely on my system.
GUI.open_file = function(path)

    local OS = reaper.GetOS()

    local cmd = ( string.match(OS, "Win") and "start" or "open" ) ..
                ' "" "' .. path .. '"'

    os.execute(cmd)

end


-- Saves the current script window parameters to an ExtState under the given section name
-- Returns dock, x, y, w, h
GUI.save_window_state = function (name, title)

    if not name then return end
    local state = {gfx.dock(-1, 0, 0, 0, 0)}
    reaper.SetExtState(name, title or "window", table.concat(state, ","), true)

    return table.unpack(state)

end


-- Looks for an ExtState containing saved window parameters
-- Returns dock, x, y, w, h
GUI.load_window_state = function (name, title)

    if not name then return end

    local str = reaper.GetExtState(name, title or "window")
    if not str or str == "" then return end

    local dock, x, y, w, h = string.match(str, "([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
    if not (dock and x and y and w and h) then return end
    GUI.dock, GUI.x, GUI.y, GUI.w, GUI.h = dock, x, y, w, h

    -- Probably don't want these messing up where the user put the window
    GUI.anchor, GUI.corner = nil, nil

    return dock, x, y, w, h

end




------------------------------------
-------- Reaper functions ----------
------------------------------------


-- Checks for Reaper's "restricted permissions" script mode
-- GUI.script_restricted will be true if restrictions are in place
-- Call GUI.error_restricted to display an error message about restricted permissions
-- and exit the script.
if not os then

    GUI.script_restricted = true

    GUI.error_restricted = function()

        reaper.MB(  "This script tried to access a function that isn't available in Reaper's 'restricted permissions' mode." ..
                    "\n\nThe script was NOT necessarily doing something malicious - restricted scripts are unable " ..
                    "to access a number of basic functions such as reading and writing files." ..
                    "\n\nPlease let the script's author know, or consider running the script without restrictions if you feel comfortable.",
                    "Script Error", 0)

        GUI.quit = true
        GUI.error_message = "(Restricted permissions error)"

        return nil, "Error: Restricted permissions"

    end

    os = setmetatable({}, { __index = GUI.error_restricted })
    io = setmetatable({}, { __index = GUI.error_restricted })

end


-- Also might need to know this
GUI.SWS_exists = reaper.APIExists("CF_GetClipboardBig")



--[[
Returns x,y coordinates for a window with the specified anchor position

If no anchor is specified, it will default to the top-left corner of the screen.
    x,y		offset coordinates from the anchor position
    w,h		window dimensions
    anchor	"screen" or "mouse"
    corner	"TL"
            "T"
            "TR"
            "R"
            "BR"
            "B"
            "BL"
            "L"
            "C"
]]--
GUI.get_window_pos = function (x, y, w, h, anchor, corner)

    local ax, ay, aw, ah = 0, 0, 0 ,0

    local __, __, scr_w, scr_h = reaper.my_getViewport(x, y, x + w, y + h,
                                                        x, y, x + w, y + h, 1)

    if anchor == "screen" then
        aw, ah = scr_w, scr_h
    elseif anchor =="mouse" then
        ax, ay = reaper.GetMousePosition()
    end

    local cx, cy = 0, 0
    if corner then
        local corners = {
            TL = 	{0, 				0},
            T =		{(aw - w) / 2, 		0},
            TR = 	{(aw - w) - 16,		0},
            R =		{(aw - w) - 16,		(ah - h) / 2},
            BR = 	{(aw - w) - 16,		(ah - h) - 40},
            B =		{(aw - w) / 2, 		(ah - h) - 40},
            BL = 	{0, 				(ah - h) - 40},
            L =	 	{0, 				(ah - h) / 2},
            C =	 	{(aw - w) / 2,		(ah - h) / 2},
        }

        cx, cy = table.unpack(corners[corner])
    end

    x = x + ax + cx
    y = y + ay + cy

--[[

    Disabled until I can figure out the multi-monitor issue

    -- Make sure the window is entirely on-screen
    local l, t, r, b = x, y, x + w, y + h

    if l < 0 then x = 0 end
    if r > scr_w then x = (scr_w - w - 16) end
    if t < 0 then y = 0 end
    if b > scr_h then y = (scr_h - h - 40) end
]]--

    return x, y

end




------------------------------------
-------- Misc. functions -----------
------------------------------------


-- Why does Lua not have an operator for this?
GUI.xor = function(a, b)

    return (a or b) and not (a and b)

end


-- Display a tooltip
GUI.settooltip = function(str)

    if not str or str == "" then return end

    --Lua: reaper.TrackCtl_SetToolTip(string fmt, integer xpos, integer ypos, boolean topmost)
    --displays tooltip at location, or removes if empty string
    local x, y = gfx.clienttoscreen(0, 0)

    reaper.TrackCtl_SetToolTip(str, x + GUI.mouse.x + 16, y + GUI.mouse.y + 16, true)
    GUI.tooltip = str


end


-- Clear the tooltip
GUI.cleartooltip = function()

    reaper.TrackCtl_SetToolTip("", 0, 0, true)
    GUI.tooltip = nil

end


-- Tab forward (or backward, if Shift is down) to the next element with .tab_idx = number.
-- Removes focus from the given element, and gives it to the new element.
function GUI.tab_to_next(elm, prev)

    if not elm.tab_idx then return end

    local inc = (prev or GUI.mouse.cap & 8 == 8) and -1 or 1

    -- Get a list of all tab_idx elements, and a list of tab_idxs
    local indices, elms = {}, {}
    for _, element in pairs(GUI.elms) do
        if element.tab_idx then
            elms[element.tab_idx] = element
            indices[#indices+1] = element.tab_idx
        end
    end

    -- This is the only element with a tab index
    if #indices == 1 then return end

    -- Find the next element in the appropriate direction
    table.sort(indices)

    local new
    local cur = GUI.table_find(indices, elm.tab_idx)

    if cur == 1 and inc == -1 then
        new = #indices
    elseif cur == #indices and inc == 1 then
        new = 1
    else
        new = cur + inc
    end

    -- Move the focus
    elm.focus = false
    elm:lostfocus()
    elm:redraw()

    -- Can't set focus until the next GUI loop or Update will have problems
    GUI.newfocus = elms[indices[new]]
    elms[indices[new]]:redraw()

end
-- NoIndex: true

--[[	Lokasenna_GUI - Button class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/TextEditor

    Creation parameters:
	name, z, x, y, w, h, caption, func[, ...]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


-- Button - New
GUI.Button = GUI.Element:new()
function GUI.Button:new(name, z, x, y, w, h, caption, func, ...)

	local Button = (not x and type(z) == "table") and z or {}

	Button.name = name
	Button.type = "Button"

	Button.z = Button.z or z

	Button.x = Button.x or x
    Button.y = Button.y or y
    Button.w = Button.w or w
    Button.h = Button.h or h

	Button.caption = Button.caption or caption

	Button.font = Button.font or 3
	Button.col_txt = Button.col_txt or "txt"
	Button.col_fill = Button.col_fill or "elm_frame"

	Button.func = Button.func or func or function () end
	Button.params = Button.params or {...}

	Button.state = 0

	GUI.redraw_z[Button.z] = true

	setmetatable(Button, self)
	self.__index = self
	return Button

end


function GUI.Button:init()

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*self.w + 4, self.h + 2)

	GUI.color(self.col_fill)
	GUI.roundrect(1, 1, self.w, self.h, 4, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(1, 1, self.w, self.h, 4, 1, 0)


	local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
	GUI.roundrect(self.w + 2, 1, self.w, self.h, 4, 1, 1)
	gfx.muladdrect(self.w + 2, 1, self.w + 2, self.h + 2, 1, 1, 1, a, 0, 0, 0, 0 )


end


function GUI.Button:ondelete()

	GUI.FreeBuffer(self.buff)

end



-- Button - Draw.
function GUI.Button:draw()

	local x, y, w, h = self.x, self.y, self.w, self.h
	local state = self.state

	-- Draw the shadow if not pressed
	if state == 0 then

		for i = 1, GUI.shadow_dist do

			gfx.blit(self.buff, 1, 0, w + 2, 0, w + 2, h + 2, x + i - 1, y + i - 1)

		end

	end

	gfx.blit(self.buff, 1, 0, 0, 0, w + 2, h + 2, x + 2 * state - 1, y + 2 * state - 1)

	-- Draw the caption
	GUI.color(self.col_txt)
	GUI.font(self.font)

    local str = self.caption
    str = str:gsub([[\n]],"\n")

	local str_w, str_h = gfx.measurestr(str)
	gfx.x = x + 2 * state + ((w - str_w) / 2)
	gfx.y = y + 2 * state + ((h - str_h) / 2)
	gfx.drawstr(str)

end


-- Button - Mouse down.
function GUI.Button:onmousedown()

	self.state = 1
	self:redraw()

end


-- Button - Mouse up.
function GUI.Button:onmouseup()

	self.state = 0

	-- If the mouse was released on the button, run func
	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then

		self.func(table.unpack(self.params))

	end
	self:redraw()

end

function GUI.Button:ondoubleclick()

	self.state = 0

	end


-- Button - Right mouse up
function GUI.Button:onmouser_up()

	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) and self.r_func then

		self.r_func(table.unpack(self.r_params))

	end
end


-- Button - Execute (extra method)
-- Used for allowing hotkeys to press a button
function GUI.Button:exec(r)

	if r then
		self.r_func(table.unpack(self.r_params))
	else
		self.func(table.unpack(self.params))
	end

end
-- NoIndex: true

--[[	Lokasenna_GUI - Frame class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Frame

    Creation parameters:
	name, z, x, y, w, h[, shadow, fill, color, round]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end



GUI.Frame = GUI.Element:new()
function GUI.Frame:new(name, z, x, y, w, h, shadow, fill, color, round)

	local Frame = (not x and type(z) == "table") and z or {}
	Frame.name = name
	Frame.type = "Frame"

	Frame.z = Frame.z or z

	Frame.x = Frame.x or x
    Frame.y = Frame.y or y
    Frame.w = Frame.w or w
    Frame.h = Frame.h or h

    if Frame.shadow == nil then
        Frame.shadow = shadow or false
    end
    if Frame.fill == nil then
        Frame.fill = fill or false
    end
	Frame.color = Frame.color or color or "elm_frame"
	Frame.round = Frame.round or round or 0

	Frame.text, Frame.last_text = Frame.text or "", ""
	Frame.txt_indent = Frame.txt_indent or 0
	Frame.txt_pad = Frame.txt_pad or 0

	Frame.bg = Frame.bg or "wnd_bg"

	Frame.font = Frame.font or 4
	Frame.col_txt = Frame.col_txt or "txt"
	Frame.pad = Frame.pad or 4

	GUI.redraw_z[Frame.z] = true

	setmetatable(Frame, self)
	self.__index = self
	return Frame

end


function GUI.Frame:init()

    self.buff = self.buff or GUI.GetBuffer()

    gfx.dest = self.buff
    gfx.setimgdim(self.buff, -1, -1)
    gfx.setimgdim(self.buff, 2 * self.w + 4, self.h + 2)

    self:drawframe()

    self:drawtext()

end


function GUI.Frame:ondelete()

	GUI.FreeBuffer(self.buff)

end


function GUI.Frame:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h

    if self.shadow then

        for i = 1, GUI.shadow_dist do

            gfx.blit(self.buff, 1, 0, w + 2, 0, w + 2, h + 2, x + i - 1, y + i - 1)

        end

    end

    gfx.blit(self.buff, 1, 0, 0, 0, w + 2, h + 2, x - 1, y - 1)

end


function GUI.Frame:val(new)

	if new ~= nil then
		self.text = new
        self:init()
		self:redraw()
	else
		return string.gsub(self.text, "\n", "")
	end

end




------------------------------------
-------- Drawing methods -----------
------------------------------------


function GUI.Frame:drawframe()

    local w, h = self.w, self.h
	local fill = self.fill
	local round = self.round

    -- Frame background
    if self.bg then
        GUI.color(self.bg)
        if round > 0 then
            GUI.roundrect(1, 1, w, h, round, 1, true)
        else
            gfx.rect(1, 1, w, h, true)
        end
    end

    -- Shadow
    local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
	GUI.roundrect(self.w + 2, 1, self.w, self.h, round, 1, 1)
	gfx.muladdrect(self.w + 2, 1, self.w + 2, self.h + 2, 1, 1, 1, a, 0, 0, 0, 0 )


    -- Frame
	GUI.color(self.color)
	if round > 0 then
		GUI.roundrect(1, 1, w, h, round, 1, fill)
	else
		gfx.rect(1, 1, w, h, fill)
	end

end


function GUI.Frame:drawtext()

	if self.text and self.text:len() > 0 then

        if self.text ~= self.last_text then
            self.text = self:wrap_text(self.text)
            self.last_text = self.text
        end

		GUI.font(self.font)
		GUI.color(self.col_txt)

		gfx.x, gfx.y = self.pad + 1, self.pad + 1
		if not fill then GUI.text_bg(self.text, self.bg) end
		gfx.drawstr(self.text)

	end

end




------------------------------------
-------- Helpers -------------------
------------------------------------


function GUI.Frame:wrap_text(text)

    return GUI.word_wrap(   text, self.font, self.w - 2*self.pad,
                            self.txt_indent, self.txt_pad)

end
--[[	Lokasenna_GUI (Team Audio addition) - Image class

    Creation parameters:
        name, z, x, y, w, h[, pixels, scale]

]]--

if not GUI then
    reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
    missing_lib = true
    return 0
end


GUI.Image = GUI.Element:new()
function GUI.Image:new(name, z, x, y, w, h, pixels, scale)

    local Image = (not x and type(z) == "table") and z or {}
    Image.name = name
    Image.type = "Image"

    Image.z = Image.z or z
    Image.x = Image.x or x
    Image.y = Image.y or y
    Image.w = Image.w or w
    Image.h = Image.h or h

    Image.pixels = Image.pixels or pixels
    Image.scale = Image.scale or scale or 1

    Image.bg = Image.bg or "wnd_bg"

    GUI.redraw_z[Image.z] = true

    setmetatable(Image, self)
    self.__index = self
    return Image

end


function GUI.Image:init()

    self.buff = self.buff or GUI.GetBuffer()

    gfx.dest = self.buff
    gfx.setimgdim(self.buff, -1, -1)
    gfx.setimgdim(self.buff, self.w, self.h)

    GUI.color(self.bg)
    gfx.rect(0, 0, self.w, self.h, true)

    self:drawpixels()

end


function GUI.Image:ondelete()

    GUI.FreeBuffer(self.buff)

end


function GUI.Image:drawpixels()

    local p = self.pixels or {}
    GUI.draw_rle_image(p)

end


function GUI.Image:draw()

    gfx.blit(self.buff, self.scale, 0, 0, 0, self.w, self.h, self.x, self.y)

end
--[[	Lokasenna_GUI (Team Audio addition) - Image Button class

    Creation parameters:
        name, z, x, y, w, h[, pixels, scale, caption, func, params...]

]]--

if not GUI then
    reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
    missing_lib = true
    return 0
end


GUI.ImageButton = GUI.Element:new()
function GUI.ImageButton:new(name, z, x, y, w, h, img_w, img_h, pixels, scale, caption, func, ...)

    local ImageButton = (not x and type(z) == "table") and z or {}

    ImageButton.name = name
    ImageButton.type = "ImageButton"

    ImageButton.z = ImageButton.z or z
    ImageButton.x = ImageButton.x or x
    ImageButton.y = ImageButton.y or y
    ImageButton.w = ImageButton.w or w
    ImageButton.h = ImageButton.h or h

    ImageButton.img_w = ImageButton.img_w or img_w
    ImageButton.img_h = ImageButton.img_h or img_h
    ImageButton.pixels = ImageButton.pixels or pixels
    ImageButton.scale = ImageButton.scale or scale or 1

    ImageButton.caption = ImageButton.caption or caption
    ImageButton.font = ImageButton.font or 3

    ImageButton.col_bg = ImageButton.col_bg or "wnd_bg"
    ImageButton.col_txt = ImageButton.col_txt or "txt"
    ImageButton.col_fill = ImageButton.col_fill or "elm_fill"
    ImageButton.col_frame = ImageButton.col_frame or "elm_frame"

    ImageButton.func = ImageButton.func or func or function () end
    ImageButton.params = ImageButton.params or {...}

    ImageButton.state = 0

    GUI.redraw_z[ImageButton.z] = true

    setmetatable(ImageButton, self)
    self.__index = self
    return ImageButton

end


function GUI.ImageButton:init()

    self.buffs = self.buffs or GUI.GetBuffer(2)

    -- Draw inactive button into buffs[1]

    gfx.dest = self.buffs[1]
    gfx.setimgdim(gfx.dest, -1, -1)
    gfx.setimgdim(gfx.dest, self.w / self.scale, self.h / self.scale)

    GUI.color(self.col_bg)
    gfx.rect(0, 0, self.w / self.scale, self.h / self.scale)
    GUI.color(self.col_frame)
    GUI.roundrect(0, 0, self.w / self.scale - 1, self.h / self.scale - 1, 8, 1, 1)

    self:drawpixels()

    -- Draw active button into buffs[2]

    gfx.dest = self.buffs[2]
    gfx.setimgdim(gfx.dest, -1, -1)
    gfx.setimgdim(gfx.dest, self.w / self.scale, self.h / self.scale)

    GUI.color(self.col_bg)
    gfx.rect(0, 0, self.w / self.scale, self.h / self.scale)
    GUI.color(self.col_fill)
    GUI.roundrect(0, 0, self.w / self.scale - 1, self.h / self.scale - 1, 8, 1, 1)

    self:drawpixels()

end


function GUI.ImageButton:ondelete()

    GUI.FreeBuffer(self.buffs)

end


function GUI.ImageButton:drawpixels()

    local p = self.pixels or {}

    GUI.font(self.font)
    local str = self.caption
    str = str:gsub([[\n]],"\n")
    local _, str_h = gfx.measurestr(str)

    local img_pad_x = (self.w / self.scale - self.img_w) / 2
    local img_pad_y = (self.h / self.scale - self.img_h - str_h / self.scale) / 2

    GUI.draw_rle_image(p, img_pad_x, img_pad_y)

end


function GUI.ImageButton:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    local state = self.state

    local buff = self.buffs[1]
    if state == 1 then
        buff = self.buffs[2]
    end

    gfx.blit(buff, self.scale, 0, 0, 0, self.w, self.h, self.x, self.y)

    -- Draw the caption
    GUI.color(self.col_txt)
    GUI.font(self.font)

    local str = self.caption
    str = str:gsub([[\n]],"\n")

    local str_w, str_h = gfx.measurestr(str)
    gfx.x = x + ((w - str_w) / 2)
    gfx.y = y + h - str_h - 8 * self.scale
    gfx.drawstr(str)

end


function GUI.ImageButton:onmousedown()

	self.state = 1
	self:redraw()

end


function GUI.ImageButton:onmouseup()

	self.state = 0

	-- If the mouse was released on the button, run func
	if GUI.IsInside(self) then

		self.func(table.unpack(self.params))

	end
	self:redraw()

end

function GUI.ImageButton:onupdate()

	if self.state == 0 and GUI.IsInside(self) then
		self.state = 1
		self:redraw()
	elseif self.state == 1 and not GUI.IsInside(self) then
		self.state = 0
		self:redraw()
	end

end
-- NoIndex: true

--[[	Lokasenna_GUI - Knob class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Knob

    Creation parameters:
	name, z, x, y, w, caption, min, max, default,[ inc, vals]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end

-- Knob - New.
GUI.Knob = GUI.Element:new()
function GUI.Knob:new(name, z, x, y, w, caption, min, max, default, inc, vals)

	local Knob = (not x and type(z) == "table") and z or {}

	Knob.name = name
	Knob.type = "Knob"

	Knob.z = Knob.z or z

	Knob.x = Knob.x or x
    Knob.y = Knob.y or y
    Knob.w = Knob.w or w
    Knob.h = Knob.w

	Knob.caption = Knob.caption or caption
	Knob.bg = Knob.bg or "wnd_bg"

    Knob.cap_x = Knob.cap_x or 0
    Knob.cap_y = Knob.cap_y or 0

	Knob.font_a = Knob.font_a or 3
	Knob.font_b = Knob.font_b or 4

	Knob.col_txt = Knob.col_txt or "txt"
	Knob.col_head = Knob.col_head or "elm_fill"
	Knob.col_body = Knob.col_body or "elm_frame"

	Knob.min = Knob.min or min
    Knob.max = Knob.max or max
    Knob.inc = Knob.inc or inc or 1


    Knob.steps = math.abs(Knob.max - Knob.min) / Knob.inc

    function Knob:formatretval(val)

        local decimal = tonumber(string.match(val, "%.(.*)") or 0)
        local places = decimal ~= 0 and string.len( decimal) or 0
        return string.format("%." .. places .. "f", val)

    end

	Knob.vals = Knob.vals or vals

	-- Determine the step angle
	Knob.stepangle = (3 / 2) / Knob.steps

	Knob.default = Knob.default or default
    Knob.curstep = Knob.default

	Knob.curval = Knob.curstep / Knob.steps

    Knob.retval = Knob:formatretval(
                ((Knob.max - Knob.min) / Knob.steps) * Knob.curstep + Knob.min
                                    )


	GUI.redraw_z[Knob.z] = true

	setmetatable(Knob, self)
	self.__index = self
	return Knob

end


function GUI.Knob:init()

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)

	-- Figure out the points of the triangle

	local r = self.w / 2
	local rp = r * 1.5
	local curangle = 0
	local o = rp + 1

	local w = 2 * rp + 2

	gfx.setimgdim(self.buff, 2*w, w)

	local side_angle = (math.acos(0.666667) / GUI.pi) * 0.9

	local Ax, Ay = GUI.polar2cart(curangle, rp, o, o)
    local Bx, By = GUI.polar2cart(curangle + side_angle, r - 1, o, o)
	local Cx, Cy = GUI.polar2cart(curangle - side_angle, r - 1, o, o)

	-- Head
	GUI.color(self.col_head)
	GUI.triangle(true, Ax, Ay, Bx, By, Cx, Cy)
	GUI.color("elm_outline")
	GUI.triangle(false, Ax, Ay, Bx, By, Cx, Cy)

	-- Body
	GUI.color(self.col_body)
	gfx.circle(o, o, r, 1)
	GUI.color("elm_outline")
	gfx.circle(o, o, r, 0)

	--gfx.blit(source, scale, rotation[, srcx, srcy, srcw, srch, destx, desty, destw, desth, rotxoffs, rotyoffs] )
	gfx.blit(self.buff, 1, 0, 0, 0, w, w, w + 1, 0)
	gfx.muladdrect(w + 1, 0, w, w, 0, 0, 0, GUI.colors["shadow"][4])

end


function GUI.Knob:ondelete()

	GUI.FreeBuffer(self.buff)

end


-- Knob - Draw
function GUI.Knob:draw()

	local x, y = self.x, self.y

	local r = self.w / 2
	local o = {x = x + r, y = y + r}


	-- Value labels
	if self.vals then self:drawvals(o, r) end

    if self.caption and self.caption ~= "" then self:drawcaption(o, r) end


	-- Figure out where the knob is pointing
	local curangle = (-5 / 4) + (self.curstep * self.stepangle)

	local blit_w = 3 * r + 2
	local blit_x = 1.5 * r

	-- Shadow
	for i = 1, GUI.shadow_dist do

		gfx.blit(   self.buff, 1, curangle * GUI.pi,
                    blit_w + 1, 0, blit_w, blit_w,
                    o.x - blit_x + i - 1, o.y - blit_x + i - 1)

	end

	-- Body
	gfx.blit(   self.buff, 1, curangle * GUI.pi,
                0, 0, blit_w, blit_w,
                o.x - blit_x - 1, o.y - blit_x - 1)

end


-- Knob - Get/set value
function GUI.Knob:val(newval)

	if newval then

        self:setcurstep(newval)

		self:redraw()

	else
		return self.retval
	end

end


-- Knob - Dragging.
function GUI.Knob:ondrag()

	local y = GUI.mouse.y
	local ly = GUI.mouse.ly

	-- Ctrl?
	local ctrl = GUI.mouse.cap&4==4

	-- Multiplier for how fast the knob turns. Higher = slower
	--					Ctrl	Normal
	local adj = ctrl and 1200 or 150

    self:setcurval( GUI.clamp(self.curval + ((ly - y) / adj), 0, 1) )

    --[[
	self.curval = self.curval + ((ly - y) / adj)
	if self.curval > 1 then self.curval = 1 end
	if self.curval < 0 then self.curval = 0 end



	self.curstep = GUI.round(self.curval * self.steps)

	self.retval = GUI.round(((self.max - self.min) / self.steps) * self.curstep + self.min)
    ]]--
	self:redraw()

end


-- Knob - Doubleclick
function GUI.Knob:ondoubleclick()
	--[[
	self.curstep = self.default
	self.curval = self.curstep / self.steps
	self.retval = GUI.round(((self.max - self.min) / self.steps) * self.curstep + self.min)
	]]--

    self:setcurstep(self.default)

	self:redraw()

end


-- Knob - Mousewheel
function GUI.Knob:onwheel()

	local ctrl = GUI.mouse.cap&4==4

	-- How many steps per wheel-step
	local fine = 1
	local coarse = math.max( GUI.round(self.steps / 30), 1)

	local adj = ctrl and fine or coarse

    self:setcurval( GUI.clamp( self.curval + (GUI.mouse.inc * adj / self.steps), 0, 1))

	self:redraw()

end



------------------------------------
-------- Drawing methods -----------
------------------------------------

function GUI.Knob:drawcaption(o, r)

    local str = self.caption

	GUI.font(self.font_a)
	local cx, cy = GUI.polar2cart(1/2, r * 2, o.x, o.y)
	local str_w, str_h = gfx.measurestr(str)
	gfx.x, gfx.y = cx - str_w / 2 + self.cap_x, cy - str_h / 2  + 8 + self.cap_y
	GUI.text_bg(str, self.bg)
	GUI.shadow(str, self.col_txt, "shadow")

end


function GUI.Knob:drawvals(o, r)

    for i = 0, self.steps do

        local angle = (-5 / 4 ) + (i * self.stepangle)

        -- Highlight the current value
        if i == self.curstep then
            GUI.color(self.col_head)
            GUI.font({GUI.fonts[self.font_b][1], GUI.fonts[self.font_b][2] * 1.2, "b"})
        else
            GUI.color(self.col_txt)
            GUI.font(self.font_b)
        end

        --local output = (i * self.inc) + self.min
        local output = self:formatretval( i * self.inc + self.min )

        if self.output then
            local t = type(self.output)

            if t == "string" or t == "number" then
                output = self.output
            elseif t == "table" then
                output = self.output[output]
            elseif t == "function" then
                output = self.output(output)
            end
        end

        -- Avoid any crashes from weird user data
        output = tostring(output)

        if output ~= "" then

            local str_w, str_h = gfx.measurestr(output)
            local cx, cy = GUI.polar2cart(angle, r * 2, o.x, o.y)
            gfx.x, gfx.y = cx - str_w / 2, cy - str_h / 2
            GUI.text_bg(output, self.bg)
            gfx.drawstr(output)
        end

    end

end




------------------------------------
-------- Value helpers -------------
------------------------------------

function GUI.Knob:setcurstep(step)

    self.curstep = step
    self.curval = self.curstep / self.steps
    self:setretval()

end


function GUI.Knob:setcurval(val)

    self.curval = val
    self.curstep = GUI.round(val * self.steps)
    self:setretval()

end


function GUI.Knob:setretval()

    self.retval = self:formatretval(self.inc * self.curstep + self.min)
    self:onchange()

end
-- NoIndex: true

--[[	Lokasenna_GUI - Label class.

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Label

    Creation parameters:
	name, z, x, y, caption[, shadow, font, color, bg]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


-- Label - New
GUI.Label = GUI.Element:new()
function GUI.Label:new(name, z, x, y, caption, shadow, font, color, bg)

	local label = (not x and type(z) == "table") and z or {}

	label.name = name
	label.type = "Label"

	label.z = label.z or z
	label.x = label.x or x
    label.y = label.y or y

    -- Placeholders; we'll get these at runtime
	label.w, label.h = 0, 0

	label.caption = label.caption   or caption
	label.shadow =  label.shadow    or shadow   or false
	label.font =    label.font      or font     or 2
	label.color =   label.color     or color    or "txt"
	label.bg =      label.bg        or bg       or "wnd_bg"


	GUI.redraw_z[label.z] = true

	setmetatable(label, self)
    self.__index = self
    return label

end


function GUI.Label:init(open)

    -- We can't do font measurements without an open window
    if gfx.w == 0 then return end

    self.buffs = self.buffs or GUI.GetBuffer(2)

    GUI.font(self.font)
    self.w, self.h = gfx.measurestr(self.caption)

    local w, h = self.w + 4, self.h + 4

    -- Because we might be doing this in mid-draw-loop,
    -- make sure we put this back the way we found it
    local dest = gfx.dest


    -- Keeping the background separate from the text to avoid graphical
    -- issues when the text is faded.
    gfx.dest = self.buffs[1]
    gfx.setimgdim(self.buffs[1], -1, -1)
    gfx.setimgdim(self.buffs[1], w, h)

    GUI.color(self.bg)
    gfx.rect(0, 0, w, h)

    -- Text + shadow
    gfx.dest = self.buffs[2]
    gfx.setimgdim(self.buffs[2], -1, -1)
    gfx.setimgdim(self.buffs[2], w, h)

    -- Text needs a background or the antialiasing will look like shit
    GUI.color(self.bg)
    gfx.rect(0, 0, w, h)

    gfx.x, gfx.y = 2, 2

    GUI.color(self.color)

	if self.shadow then
        GUI.shadow(self.caption, self.color, "shadow")
    else
        gfx.drawstr(self.caption)
    end

    gfx.dest = dest

end


function GUI.Label:ondelete()

	GUI.FreeBuffer(self.buffs)

end


function GUI.Label:fade(len, z_new, z_end, curve)

	self.z = z_new
	self.fade_arr = { len, z_end, reaper.time_precise(), curve or 3 }
	self:redraw()

end


function GUI.Label:draw()

    -- Font stuff doesn't work until we definitely have a gfx window
	if self.w == 0 then self:init() end

    local a = self.fade_arr and self:getalpha() or 1
    if a == 0 then return end

    gfx.x, gfx.y = self.x - 2, self.y - 2

    -- Background
    gfx.blit(self.buffs[1], 1, 0)

    gfx.a = a

    -- Text
    gfx.blit(self.buffs[2], 1, 0)

    gfx.a = 1

end


function GUI.Label:val(newval)

	if newval then
		self.caption = newval
		self:init()
		self:redraw()
	else
		return self.caption
	end

end


function GUI.Label:getalpha()

    local sign = self.fade_arr[4] > 0 and 1 or -1

    local diff = (reaper.time_precise() - self.fade_arr[3]) / self.fade_arr[1]
    diff = math.floor(diff * 100) / 100
    diff = diff^(math.abs(self.fade_arr[4]))

    local a = sign > 0 and (1 - (gfx.a * diff)) or (gfx.a * diff)

    self:redraw()

    -- Terminate the fade loop at some point
    if sign == 1 and a < 0.02 then
        self.z = self.fade_arr[2]
        self.fade_arr = nil
        return 0
    elseif sign == -1 and a > 0.98 then
        self.fade_arr = nil
    end

    return a

end
-- NoIndex: true

--[[	Lokasenna_GUI - Listbox class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Listbox

    Creation parameters:
	name, z, x, y, w, h[, list, multi, caption, pad, bar_w]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end

-- Listbox - New
GUI.Listbox = GUI.Element:new()
function GUI.Listbox:new(name, z, x, y, w, h, list, multi, caption, pad, bar_w)

	local lst = (not x and type(z) == "table") and z or {}

	lst.name = name
	lst.type = "Listbox"

	lst.z = lst.z or z

	lst.x = lst.x or x
    lst.y = lst.y or y
    lst.w = lst.w or w
    lst.h = lst.h or h

	lst.list = lst.list or list or {}
	lst.retval = lst.retval or {}

    if lst.multi == nil then
        lst.multi = multi or false
    end

	lst.caption = lst.caption or caption or ""
	lst.pad = lst.pad or pad or 4
	lst.bar_w = lst.bar_w or bar_w or 8

    if lst.shadow == nil then
        lst.shadow = true
    end
	lst.bg = lst.bg or "elm_bg"
    lst.cap_bg = lst.cap_bg or "wnd_bg"
	lst.color = lst.color or "txt"

	-- Scrollbar fill
	lst.col_fill = lst.col_fill or "elm_fill"

	lst.font_a = lst.font_a or 3

	lst.font_b = lst.font_b or 4

	lst.wnd_y = 1

	lst.wnd_h, lst.wnd_w, lst.char_w = nil, nil, nil

	GUI.redraw_z[lst.z] = true

	setmetatable(lst, self)
	self.__index = self
	return lst

end


function GUI.Listbox:init()

	-- If we were given a CSV, process it into a table
	if type(self.list) == "string" then self.list = self:CSVtotable(self.list) end

	local x, y, w, h = self.x, self.y, self.w, self.h

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, w, h)

	GUI.color(self.bg)
	gfx.rect(0, 0, w, h, 1)

	GUI.color("elm_frame")
	gfx.rect(0, 0, w, h, 0)


end


function GUI.Listbox:ondelete()

	GUI.FreeBuffer(self.buff)

end


function GUI.Listbox:draw()


	local x, y, w, h = self.x, self.y, self.w, self.h

	local caption = self.caption
	local pad = self.pad

	-- Some values can't be set in :init() because the window isn't
	-- open yet - measurements won't work.
	if not self.wnd_h then self:wnd_recalc() end

	-- Draw the caption
	if caption and caption ~= "" then self:drawcaption() end

	-- Draw the background and frame
	gfx.blit(self.buff, 1, 0, 0, 0, w, h, x, y)

	-- Draw the text
	self:drawtext()

	-- Highlight any selected items
	self:drawselection()

	-- Vertical scrollbar
	if #self.list > self.wnd_h then self:drawscrollbar() end

end


function GUI.Listbox:val(newval)

	if newval then
		--self.list = type(newval) == "string" and self:CSVtotable(newval) or newval
        if type(newval) == "table" then

            for i = 1, #self.list do
                self.retval[i] = newval[i] or nil
            end

        elseif type(newval) == "number" then

            newval = math.floor(newval)
            for i = 1, #self.list do
                self.retval[i] = (i == newval)
            end

        end

		self:onchange()
		self:redraw()

	else

		if self.multi then
			return self.retval
		else
			for k, v in pairs(self.retval) do
				return k
			end
		end

	end

end


---------------------------------
------ Input methods ------------
---------------------------------


function GUI.Listbox:onmouseup()

	if not self:overscrollbar() then

		local item = self:getitem(GUI.mouse.y)

		if self.multi then

			-- Ctrl
			if GUI.mouse.cap & 4 == 4 then

				self.retval[item] = not self.retval[item]

			-- Shift
			elseif GUI.mouse.cap & 8 == 8 then

				self:selectrange(item)

			else

				self.retval = {[item] = true}

			end

		else

			self.retval = {[item] = true}

		end

	end

	self:onchange()
	self:redraw()

end


function GUI.Listbox:onmousedown(scroll)

	-- If over the scrollbar, or we came from :ondrag with an origin point
	-- that was over the scrollbar...
	if scroll or self:overscrollbar() then

        local wnd_c = GUI.round( ((GUI.mouse.y - self.y) / self.h) * #self.list  )
		self.wnd_y = math.floor( GUI.clamp(1, wnd_c - (self.wnd_h / 2), #self.list - self.wnd_h + 1) )

		self:redraw()

	end

end


function GUI.Listbox:ondrag()

	if self:overscrollbar(GUI.mouse.ox) then

		self:onmousedown(true)

	-- Drag selection?
	else


	end

	self:redraw()

end


function GUI.Listbox:onwheel(inc)

	local dir = inc > 0 and -1 or 1

	-- Scroll up/down one line
	self.wnd_y = GUI.clamp(1, self.wnd_y + dir, math.max(#self.list - self.wnd_h + 1, 1))

	self:redraw()

end


---------------------------------
-------- Drawing methods---------
---------------------------------


function GUI.Listbox:drawcaption()

	local str = self.caption

	GUI.font(self.font_a)
	local str_w, str_h = gfx.measurestr(str)
	gfx.x = self.x - str_w - self.pad
	gfx.y = self.y + self.pad
	GUI.text_bg(str, self.cap_bg)

	if self.shadow then
		GUI.shadow(str, self.color, "shadow")
	else
		GUI.color(self.color)
		gfx.drawstr(str)
	end

end


function GUI.Listbox:drawtext()

	GUI.color(self.color)
	GUI.font(self.font_b)

	local tmp = {}
	for i = self.wnd_y, math.min(self:wnd_bottom() - 1, #self.list) do

		local str = tostring(self.list[i]) or ""
        tmp[#tmp + 1] = str

	end

	gfx.x, gfx.y = self.x + self.pad, self.y + self.pad
    local r = gfx.x + self.w - 2*self.pad
    local b = gfx.y + self.h - 2*self.pad
	gfx.drawstr( table.concat(tmp, "\n"), 0, r, b)

end


function GUI.Listbox:drawselection()

	local off_x, off_y = self.x + self.pad, self.y + self.pad
	local x, y, w, h

	w = self.w - 2 * self.pad

	GUI.color("elm_fill")
	gfx.a = 0.5
	gfx.mode = 1
	-- for wnd_y, wnd_y + wnd_h do

	for i = 1, #self.list do

		if self.retval[i] and i >= self.wnd_y and i < self:wnd_bottom() then

			y = off_y + (i - self.wnd_y) * self.char_h
			gfx.rect(off_x, y, w, self.char_h, true)

		end

	end

	gfx.mode = 0
	gfx.a = 1

end


function GUI.Listbox:drawscrollbar()

	local x, y, w, h = self.x, self.y, self.w, self.h
	local sx, sy, sw, sh = x + w - self.bar_w - 4, y + 4, self.bar_w, h - 12


	-- Draw a gradient to fade out the last ~16px of text
	GUI.color("elm_bg")
	for i = 0, 15 do
		gfx.a = i/15
		gfx.line(sx + i - 15, y + 2, sx + i - 15, y + h - 4)
	end

	gfx.rect(sx, y + 2, sw + 2, h - 4, true)

	-- Draw slider track
	GUI.color("tab_bg")
	GUI.roundrect(sx, sy, sw, sh, 4, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(sx, sy, sw, sh, 4, 1, 0)

	-- Draw slider fill
	local fh = (self.wnd_h / #self.list) * sh - 4
	if fh < 4 then fh = 4 end
	local fy = sy + ((self.wnd_y - 1) / #self.list) * sh + 2

	GUI.color(self.col_fill)
	GUI.roundrect(sx + 2, fy, sw - 4, fh, 2, 1, 1)

end


---------------------------------
-------- Helpers ----------------
---------------------------------


-- Updates internal values for the window size
function GUI.Listbox:wnd_recalc()

	GUI.font(self.font_b)

    self.char_w, self.char_h = gfx.measurestr("_")
	self.wnd_h = math.floor((self.h - 2*self.pad) / self.char_h)
	self.wnd_w = math.floor(self.w / self.char_w)

end


-- Get the bottom edge of the window (in rows)
function GUI.Listbox:wnd_bottom()

	return self.wnd_y + self.wnd_h

end


-- Determine which item the user clicked
function GUI.Listbox:getitem(y)

	--local item = math.floor( ( (y - self.y) / self.h ) * self.wnd_h) + self.wnd_y

	GUI.font(self.font_b)

	local item = math.floor(	(y - (self.y + self.pad))
								/	self.char_h)
				+ self.wnd_y

	item = GUI.clamp(1, item, #self.list)

	return item

end


-- Split a CSV into a table
function GUI.Listbox:CSVtotable(str)

	local tmp = {}
	for line in string.gmatch(str, "([^,]+)") do
		table.insert(tmp, line)
	end

	return tmp

end


-- Is the mouse over the scrollbar (true) or the text area (false)?
function GUI.Listbox:overscrollbar(x)

	return (#self.list > self.wnd_h and (x or GUI.mouse.x) >= (self.x + self.w - self.bar_w - 4))

end


-- Selects all items
function GUI.Listbox:selectall()
  self.retval = {}
  for i = 1, #self.list do
    self.retval[i] = true
  end
end


-- Selects from the first selected item to the current mouse position
function GUI.Listbox:selectrange(mouse)

	-- Find the first selected item
	local first
	for k, v in pairs(self.retval) do
		first = first and math.min(k, first) or k
	end

	if not first then first = 1 end

	self.retval = {}

	-- Select everything between the first selected item and the mouse
	for i = mouse, first, (first > mouse and 1 or -1) do
		self.retval[i] = true
	end

end
-- NoIndex: true

--[[	Lokasenna_GUI - Menubar clas

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Menubar

    Creation parameters:
	name, z, x, y, menus[, w, h, pad]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


GUI.Menubar = GUI.Element:new()
function GUI.Menubar:new(name, z, x, y, menus, w, h, pad) -- Add your own params here

	local mnu = (not x and type(z) == "table") and z or {}

	mnu.name = name
	mnu.type = "Menubar"

	mnu.z = mnu.z or z

	mnu.x = mnu.x or x
    mnu.y = mnu.y or y

    mnu.font = mnu.font or 2
    mnu.col_txt = mnu.col_txt or "txt"
    mnu.col_bg = mnu.col_bg or "elm_frame"
    mnu.col_over = mnu.col_over or "elm_fill"

    if mnu.shadow == nil then
        mnu.shadow = true
    end

    mnu.w = mnu.w or w
    mnu.h = mnu.h or h

    if mnu.fullwidth == nil then
        mnu.fullwidth = true
    end

    -- Optional parameters should be given default values to avoid errors/crashes:
    mnu.pad = mnu.pad or pad or 0

    mnu.menus = mnu.menus or menus

	GUI.redraw_z[mnu.z] = true

	setmetatable(mnu, self)
	self.__index = self
	return mnu

end


function GUI.Menubar:init()

    if gfx.w == 0 then return end

    self.buff = self.buff or GUI.GetBuffer()

    -- We'll have to reset this manually since we're not running :init()
    -- until after the window is open
    local dest = gfx.dest

    gfx.dest = self.buff
    gfx.setimgdim(self.buff, -1, -1)


    -- Store some text measurements
    GUI.font(self.font)

    self.tab = gfx.measurestr(" ") * 4

    for i = 1, #self.menus do

        self.menus[i].width = gfx.measurestr(self.menus[i].title)

    end

    self.w = self.w or 0
    self.w = self.fullwidth and (GUI.cur_w - self.x) or math.max(self.w, self:measuretitles(nil, true))
    self.h = self.h or gfx.texth


    -- Draw the background + shadow
    gfx.setimgdim(self.buff, self.w, self.h * 2)

    GUI.color(self.col_bg)

    gfx.rect(0, 0, self.w, self.h, true)

    GUI.color("shadow")
    local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
    gfx.rect(0, self.h + 1, self.w, self.h, true)
    gfx.muladdrect(0, self.h + 1, self.w, self.h, 1, 1, 1, a, 0, 0, 0, 0 )

    self.did_init = true

    gfx.dest = dest

end


function GUI.Menubar:ondelete()

	GUI.FreeBuffer(self.buff)

end



function GUI.Menubar:draw()

    if not self.did_init then self:init() end

    local x, y = self.x, self.y
    local w, h = self.w, self.h

    -- Blit the menu background + shadow
    if self.shadow then

        for i = 1, GUI.shadow_dist do

            gfx.blit(self.buff, 1, 0, 0, h, w, h, x, y + i, w, h)

        end

    end

    gfx.blit(self.buff, 1, 0, 0, 0, w, h, x, y, w, h)

    -- Draw menu titles
    self:drawtitles()

    -- Draw highlight
    if self.mousemnu then self:drawhighlight() end

end


function GUI.Menubar:val(newval)

    if newval and type(newval) == "table" then

        self.menus = newval
        self.w, self.h = nil, nil
        self:init()
        self:redraw()

    else

        return self.menus

    end

end


function GUI.Menubar:onresize()

    if self.fullwidth then
        self:init()
        self:redraw()
    end

end


------------------------------------
-------- Drawing methods -----------
------------------------------------


function GUI.Menubar:drawtitles()

    local x = self.x

    GUI.font(self.font)
    GUI.color(self.col_txt)

    for i = 1, #self.menus do

        local str = self.menus[i].title
        local str_w, _ = gfx.measurestr(str)

        gfx.x = x + (self.tab + self.pad) / 2
        gfx.y = self.y

        gfx.drawstr(str)

        x = x + str_w + self.tab + self.pad

    end

end


function GUI.Menubar:drawhighlight()

    if self.menus[self.mousemnu].title == "" then return end

    GUI.color(self.col_over)
    gfx.mode = 1
    --                                Hover  Click
    gfx.a = GUI.mouse.cap & 1 ~= 1 and 0.3 or 0.5

    gfx.rect(self.x + self.mousemnu_x, self.y, self.menus[self.mousemnu].width + self.tab + self.pad, self.h, true)

    gfx.a = 1
    gfx.mode = 0

end




------------------------------------
-------- Input methods -------------
------------------------------------


-- Make sure to disable the highlight if the mouse leaves
function GUI.Menubar:onupdate()

    if self.mousemnu and not GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then
        self.mousemnu = nil
        self.mousemnu_x = nil
        self:redraw()

        -- Skip the rest of the update loop for this elm
        return true
    end

end



function GUI.Menubar:onmouseup()

    if not self.mousemnu then return end

    gfx.x, gfx.y = self.x + self:measuretitles(self.mousemnu - 1, true), self.y + self.h
    local menu_str, sep_arr = self:prepmenu()
    local opt = gfx.showmenu(menu_str)

	if #sep_arr > 0 then opt = self:stripseps(opt, sep_arr) end

    if opt > 0 then

       self.menus[self.mousemnu].options[opt][2]()

    end

	self:redraw()

end


function GUI.Menubar:onmousedown()

    self:redraw()

end


function GUI.Menubar:onmouseover()

    local opt = self.mousemnu

    local x = GUI.mouse.x - self.x

    if  self.mousemnu_x and x > self:measuretitles(nil, true) then

        self.mousemnu = nil
        self.mousemnu_x = nil
        self:redraw()

        return

    end


    -- Iterate through the titles by overall width until we
    -- find which one the mouse is in.
    for i = 1, #self.menus do

        if x <= self:measuretitles(i, true) then

            self.mousemnu = i
            self.mousemnu_x = self:measuretitles(i - 1, true)

            if self.mousemnu ~= opt then self:redraw() end

            return
        end

    end

end


function GUI.Menubar:ondrag()

    self:onmouseover()

end


------------------------------------
-------- Menu methods --------------
------------------------------------


-- Return a table of the menu titles
function GUI.Menubar:gettitles()

   local tmp = {}
   for i = 1, #self.menus do
       tmp[i] = self.menus.title
   end

   return tmp

end


-- Returns the length of the specified number of menu titles, or
-- all of them if 'num' isn't given
-- Will include tabs + padding if tabs = true
function GUI.Menubar:measuretitles(num, tabs)

    local len = 0

    for i = 1, num or #self.menus do

        len = len + self.menus[i].width

    end

    return not tabs and len
                    or (len + (self.tab + self.pad) * (num or #self.menus))

end


-- Parse the current menu into a string for gfx.showmenu
-- Returns the string and a table of separators for offsetting the
-- value returned when the user clicks something.
function GUI.Menubar:prepmenu()

    local arr = self.menus[self.mousemnu].options

    local sep_arr = {}
	local str_arr = {}
    local menu_str = ""

	for i = 1, #arr do

        table.insert(str_arr, arr[i][1])

		if str_arr[#str_arr] == ""
		or string.sub(str_arr[#str_arr], 1, 1) == ">" then
			table.insert(sep_arr, i)
		end

		table.insert( str_arr, "|" )

	end

	menu_str = table.concat( str_arr )

	return string.sub(menu_str, 1, string.len(menu_str) - 1), sep_arr

end


-- Adjust the returned value to account for any separators,
-- since gfx.showmenu doesn't count them
function GUI.Menubar:stripseps(opt, sep_arr)

    for i = 1, #sep_arr do
        if opt >= sep_arr[i] then
            opt = opt + 1
        else
            break
        end
    end

    return opt

end
-- NoIndex: true

--[[	Lokasenna_GUI - MenuBox class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Menubox

    Creation parameters:
  name, z, x, y, w, h, caption, opts[, pad, arrow]

]]--

if not GUI then
  reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
  missing_lib = true
  return 0
end


GUI.Menubox = GUI.Element:new()
function GUI.Menubox:new(name, z, x, y, w, h, caption, opts, pad, arrow)

  local menu = (not x and type(z) == "table") and z or {}

  menu.name = name
  menu.type = "Menubox"

  menu.z = menu.z or z


  menu.x = menu.x or x
    menu.y = menu.y or y
    menu.w = menu.w or w
    menu.h = menu.h or h

  menu.caption = menu.caption or caption
  menu.bg = menu.bg or "wnd_bg"

  menu.font_a = menu.font_a or 3
  menu.font_b = menu.font_b or 4

  menu.col_cap = menu.col_cap or "txt"
  menu.col_txt = menu.col_txt or "txt"

  menu.pad = menu.pad or pad or 4

  if menu.arrow == nil then

      menu.arrow = arrow or 5

  end
  menu.align = menu.align or 0

  menu.retval = menu.retval or 1

  local opts = menu.opts or opts

  if not opts then

    menu.optarray = menu.optarray or {" "}

  elseif type(opts) == "string" then

    if opts == "" then opts = " " end

    -- Parse the string of options into a table
    menu.optarray = {}

    for word in string.gmatch(opts, '([^,]*)') do
        menu.optarray[#menu.optarray+1] = word
    end
  elseif type(opts) == "table" then
      menu.optarray = opts
      if #menu.optarray == 0 then menu.optarray = {" "} end
  end

  GUI.redraw_z[menu.z] = true

  setmetatable(menu, self)
    self.__index = self
    return menu

end


function GUI.Menubox:init()

  local w, h = self.w, self.h

  self.buff = self.buff or GUI.GetBuffer()

  gfx.dest = self.buff
  gfx.setimgdim(self.buff, -1, -1)
  gfx.setimgdim(self.buff, 2*w + 4, 2*h + 4)

    self:drawframe()

    if self.arrow then self:drawarrow() end

end


function GUI.Menubox:ondelete()

	GUI.FreeBuffer(self.buff)

end


function GUI.Menubox:draw()

  local x, y, w, h = self.x, self.y, self.w, self.h

  local caption = self.caption
  local focus = self.focus


  -- Draw the caption
  if caption and caption ~= "" then self:drawcaption() end


    -- Blit the shadow + frame
  for i = 1, GUI.shadow_dist do
    gfx.blit(self.buff, 1, 0, w + 2, 0, w + 2, h + 2, x + i - 1, y + i - 1)
  end

  gfx.blit(self.buff, 1, 0, 0, (focus and (h + 2) or 0) , w + 2, h + 2, x - 1, y - 1)

    -- Draw the text
    self:drawtext()

end


function GUI.Menubox:val(newval)

  if newval then
    self:setretval(newval)
    self:redraw()
  else
    return math.floor(self.retval), self.optarray[self.retval]
  end

end


function GUI.Menubox:setretval(val)
  if self.retval ~= val then
    self.retval = val
    self:onchange()
  end
end




------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Menubox:onmouseup()

    -- Bypass option for GUI Builder
    if not self.focus then
        self:redraw()
        return
    end

  -- The menu doesn't count separators in the returned number,
  -- so we'll do it here
  local menu_str, sep_arr = self:prepmenu()

  gfx.x, gfx.y = GUI.mouse.x, GUI.mouse.y
  local curopt = gfx.showmenu(menu_str)

  if #sep_arr > 0 then curopt = self:stripseps(curopt, sep_arr) end
  if curopt ~= 0 then self:setretval(curopt) end

  self.focus = false
  self:redraw()

end


-- This is only so that the box will light up
function GUI.Menubox:onmousedown()
  self:redraw()
end


function GUI.Menubox:onwheel()

  -- Avert a crash if there aren't at least two items in the menu
  --if not self.optarray[2] then return end

  -- Check for illegal values, separators, and submenus
  self:setretval(self:validateoption(  GUI.round(self.retval - GUI.mouse.inc),
                                       GUI.round((GUI.mouse.inc > 0) and 1 or -1) ))

  self:redraw()

end


------------------------------------
-------- Drawing methods -----------
------------------------------------


function GUI.Menubox:drawframe()

    local x, y, w, h = self.x, self.y, self.w, self.h
  local r, g, b, a = table.unpack(GUI.colors["shadow"])
  gfx.set(r, g, b, 1)
  gfx.rect(w + 3, 1, w, h, 1)
  gfx.muladdrect(w + 3, 1, w + 2, h + 2, 1, 1, 1, a, 0, 0, 0, 0 )

  GUI.color("elm_bg")
  gfx.rect(1, 1, w, h)
  gfx.rect(1, w + 3, w, h)

  GUI.color("elm_frame")
  gfx.rect(1, 1, w, h, 0)
  if self.arrow then gfx.rect(1 + w - h, 1, h, h, 1) end

  GUI.color("elm_fill")
  gfx.rect(1, h + 3, w, h, 0)
  gfx.rect(2, h + 4, w - 2, h - 2, 0)

end


function GUI.Menubox:drawarrow()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.rect(1 + w - h, h + 3, h, h, 1)

    GUI.color("elm_bg")

    -- Triangle size
    local r = self.arrow
    local rh = 2 * r / 5

    local ox = (1 + w - h) + h / 2
    local oy = 1 + h / 2 - (r / 2)

    local Ax, Ay = GUI.polar2cart(1/2, r, ox, oy)
    local Bx, By = GUI.polar2cart(0, r, ox, oy)
    local Cx, Cy = GUI.polar2cart(1, r, ox, oy)

    GUI.triangle(true, Ax, Ay, Bx, By, Cx, Cy)

    oy = oy + h + 2

    Ax, Ay = GUI.polar2cart(1/2, r, ox, oy)
    Bx, By = GUI.polar2cart(0, r, ox, oy)
    Cx, Cy = GUI.polar2cart(1, r, ox, oy)

    GUI.triangle(true, Ax, Ay, Bx, By, Cx, Cy)

end


function GUI.Menubox:drawcaption()

    GUI.font(self.font_a)
    local str_w, str_h = gfx.measurestr(self.caption)

    gfx.x = self.x - str_w - self.pad
    gfx.y = self.y + (self.h - str_h) / 2

    GUI.text_bg(self.caption, self.bg)
    GUI.shadow(self.caption, self.col_cap, "shadow")

end


function GUI.Menubox:drawtext()

    -- Make sure retval hasn't been accidentally set to something illegal
    self.retval = self:validateoption(tonumber(self.retval) or 1)

    -- Strip gfx.showmenu's special characters from the displayed value
  local text = string.match(self.optarray[self.retval], "^[<!#]?(.+)")

  -- Draw the text
  GUI.font(self.font_b)
  GUI.color(self.col_txt)

  --if self.output then text = self.output(text) end

    if self.output then
        local t = type(self.output)

        if t == "string" or t == "number" then
            text = self.output
        elseif t == "table" then
            text = self.output[text]
        elseif t == "function" then
            text = self.output(text)
        end
    end

    -- Avoid any crashes from weird user data
    text = tostring(text)

    str_w, str_h = gfx.measurestr(text)
  gfx.x = self.x + 4
  gfx.y = self.y + (self.h - str_h) / 2

    local r = gfx.x + self.w - 8 - (self.arrow and self.h or 0)
    local b = gfx.y + str_h
  gfx.drawstr(text, self.align, r, b)

end


------------------------------------
-------- Input helpers -------------
------------------------------------


-- Put together a string for gfx.showmenu from the values in optarray
function GUI.Menubox:prepmenu()

  local str_arr = {}
    local sep_arr = {}
    local menu_str = ""

  for i = 1, #self.optarray do

    -- Check off the currently-selected option
    if i == self.retval then menu_str = menu_str .. "!" end

        table.insert(str_arr, tostring( type(self.optarray[i]) == "table"
                                            and self.optarray[i][1]
                                            or  self.optarray[i]
                                      )
                    )

    if str_arr[#str_arr] == ""
    or string.sub(str_arr[#str_arr], 1, 1) == ">" then
      table.insert(sep_arr, i)
    end

    table.insert( str_arr, "|" )

  end

  menu_str = table.concat( str_arr )

  return string.sub(menu_str, 1, string.len(menu_str) - 1), sep_arr

end


-- Adjust the menu's returned value to ignore any separators ( --------- )
function GUI.Menubox:stripseps(curopt, sep_arr)

    for i = 1, #sep_arr do
        if curopt >= sep_arr[i] then
            curopt = curopt + 1
        else
            break
        end
    end

    return curopt

end


function GUI.Menubox:validateoption(val, dir)

    dir = dir or 1

    while true do

        -- Past the first option, look upward instead
        if val < 1 then
            val = 1
            dir = 1

        -- Past the last option, look downward instead
        elseif val > #self.optarray then
            val = #self.optarray
            dir = -1

        end

        -- Don't stop on separators, folders, or grayed-out options
        local opt = string.sub(self.optarray[val], 1, 1)
        if opt == "" or opt == ">" or opt == "#" then
            val = val - dir

        -- This option is good
        else
            break
        end

    end

    return val

end
-- NoIndex: true

--[[	Lokasenna_GUI - Options classes

    This file provides two separate element classes:

    Radio       A list of options from which the user can only choose one at a time.
    Checklist   A list of options from which the user can choose any, all or none.

    Both classes take the same parameters on creation, and offer the same parameters
    afterward - their usage only differs when it comes to their respective :val methods.

    For documentation, see the class pages on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Checklist
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Radio

    Creation parameters:
	name, z, x, y, w, h, caption, opts[, dir, pad]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


local Option = GUI.Element:new()

function Option:new(name, z, x, y, w, h, caption, opts, dir, pad)

	local option = (not x and type(z) == "table") and z or {}

	option.name = name
	option.type = "Option"

	option.z = option.z or z

	option.x = option.x or x
    option.y = option.y or y
    option.w = option.w or w
    option.h = option.h or h

	option.caption = option.caption or caption

    if option.frame == nil then
        option.frame = true
    end
	option.bg = option.bg or "wnd_bg"

	option.dir = option.dir or dir or "v"
	option.pad = option.pad or pad or 4

	option.col_txt = option.col_txt or "txt"
	option.col_fill = option.col_fill or "elm_fill"

	option.font_a = option.font_a or 2
	option.font_b = option.font_b or 3

    if option.shadow == nil then
        option.shadow = true
    end

    if option.shadow == nil then
        option.swap = false
    end

	-- Size of the option bubbles
	option.opt_size = option.opt_size or 20

	-- Parse the string of options into a table
    if not option.optarray then
        option.optarray = {}

        local opts = option.opts or opts

        if type(opts) == "table" then

            for i = 1, #opts do
                option.optarray[i] = opts[i]
            end

        else

            local tempidx = 1
            for word in string.gmatch(opts, '([^,]*)') do
                option.optarray[tempidx] = word
                tempidx = tempidx + 1
            end

        end
    end

	GUI.redraw_z[option.z] = true

	setmetatable(option, self)
    self.__index = self
    return option

end


function Option:init()

    -- Make sure we're not trying to use the base class.
    if self.type == "Option" then
        reaper.ShowMessageBox(  "'"..self.name.."' was initialized as an Option element,"..
                                "but Option doesn't do anything on its own!",
                                "GUI Error", 0)

        GUI.quit = true
        return

    end

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*self.opt_size + 4, 2*self.opt_size + 2)


    self:initoptions()


	if self.caption and self.caption ~= "" then
		GUI.font(self.font_a)
		local str_w, str_h = gfx.measurestr(self.caption)
		self.cap_h = 0.5*str_h
		self.cap_x = self.x + (self.w - str_w) / 2
	else
		self.cap_h = 0
		self.cap_x = 0
	end

end


function Option:ondelete()

	GUI.FreeBuffer(self.buff)

end


function Option:draw()

	if self.frame then
		GUI.color("elm_frame")
		gfx.rect(self.x, self.y, self.w, self.h, 0)
	end

    if self.caption and self.caption ~= "" then self:drawcaption() end

    self:drawoptions()

end




------------------------------------
-------- Input helpers -------------
------------------------------------




function Option:getmouseopt()

    local len = #self.optarray

	-- See which option it's on
	local mouseopt = self.dir == "h"
                    and (GUI.mouse.x - (self.x + self.pad))
					or	(GUI.mouse.y - (self.y + self.cap_h + 1.5*self.pad) )

	mouseopt = mouseopt / ((self.opt_size + self.pad) * len)
	mouseopt = GUI.clamp( math.floor(mouseopt * len) + 1 , 1, len )

    return self.optarray[mouseopt] ~= "_" and mouseopt or false

end


------------------------------------
-------- Drawing methods -----------
------------------------------------


function Option:drawcaption()

    GUI.font(self.font_a)

    gfx.x = self.cap_x
    gfx.y = self.y - self.cap_h

    GUI.text_bg(self.caption, self.bg)

    GUI.shadow(self.caption, self.col_txt, "shadow")

end


function Option:drawoptions()

    local x, y, w, h = self.x, self.y, self.w, self.h

    local horz = self.dir == "h"
	local pad = self.pad

    -- Bump everything down for the caption
    y = y + ((self.caption and self.caption ~= "") and self.cap_h or 0) + 1.5 * pad

    -- Bump the options down more for horizontal options
    -- with the text on top
	if horz and self.caption ~= "" and not self.swap then
        y = y + self.cap_h + 2*pad
    end

	local opt_size = self.opt_size

    local adj = opt_size + pad

    local str, opt_x, opt_y

	for i = 1, #self.optarray do

		str = self.optarray[i]
		if str ~= "_" then

            opt_x = x + (horz   and (i - 1) * adj + pad
                                or  (self.swap  and (w - adj - 1)
                                                or   pad))

            opt_y = y + (i - 1) * (horz and 0 or adj)

			-- Draw the option bubble
            self:drawoption(opt_x, opt_y, opt_size, self:isoptselected(i))

            self:drawvalue(opt_x,opt_y, opt_size, str)

		end

	end

end


function Option:drawoption(opt_x, opt_y, size, selected)

    gfx.blit(   self.buff, 1,  0,
                selected and (size + 3) or 1, 1,
                size + 1, size + 1,
                opt_x, opt_y)

end


function Option:drawvalue(opt_x, opt_y, size, str)

    if not str or str == "" then return end

	GUI.font(self.font_b)

    local str_w, str_h = gfx.measurestr(str)

    if self.dir == "h" then

        gfx.x = opt_x + (size - str_w) / 2
        gfx.y = opt_y + (self.swap and (size + 4) or -size)

    else

        gfx.x = opt_x + (self.swap and -(str_w + 8) or 1.5*size)
        gfx.y = opt_y + (size - str_h) / 2

    end

    GUI.text_bg(str, self.bg)
    if #self.optarray == 1 or self.shadow then
        GUI.shadow(str, self.col_txt, "shadow")
    else
        GUI.color(self.col_txt)
        gfx.drawstr(str)
    end

end




------------------------------------
-------- Radio methods -------------
------------------------------------


GUI.Radio = {}
setmetatable(GUI.Radio, {__index = Option})

function GUI.Radio:new(name, z, x, y, w, h, caption, opts, dir, pad)

    local radio = Option:new(name, z, x, y, w, h, caption, opts, dir, pad)

    radio.type = "Radio"

    radio.retval, radio.state = 1, 1

    setmetatable(radio, self)
    self.__index = self
    return radio

end


function GUI.Radio:initoptions()

	local r = self.opt_size / 2

	-- Option bubble
	GUI.color(self.bg)
	gfx.circle(r + 1, r + 1, r + 2, 1, 0)
	gfx.circle(3*r + 3, r + 1, r + 2, 1, 0)
	GUI.color("elm_frame")
	gfx.circle(r + 1, r + 1, r, 0)
	gfx.circle(3*r + 3, r + 1, r, 0)
	GUI.color(self.col_fill)
	gfx.circle(3*r + 3, r + 1, 0.5*r, 1)


end


function GUI.Radio:val(newval)

	if newval ~= nil then
		self.retval = newval
		self.state = newval
		self:onchange()
		self:redraw()
	else
		return self.retval
	end

end


function GUI.Radio:onmousedown()

	self.state = self:getmouseopt() or self.state

	self:redraw()

end


function GUI.Radio:onmouseup()

    -- Bypass option for GUI Builder
    if not self.focus then
        self:redraw()
        return
    end

	-- Set the new option, or revert to the original if the cursor
    -- isn't inside the list anymore
	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then
		self.retval = self.state
		self:onchange()
	else
		self.state = self.retval
	end

    self.focus = false
	self:redraw()

end


function GUI.Radio:ondrag()

	self:onmousedown()

	self:redraw()

end


function GUI.Radio:onwheel()
--[[
	state = GUI.round(self.state +     (self.dir == "h" and 1 or -1)
                                    *   GUI.mouse.inc)
]]--

    self.state = self:getnextoption(    GUI.xor( GUI.mouse.inc > 0, self.dir == "h" )
                                        and -1
                                        or 1 )

	--if self.state < 1 then self.state = 1 end
	--if self.state > #self.optarray then self.state = #self.optarray end

	self.retval = self.state

	self:onchange()
	self:redraw()

end


function GUI.Radio:isoptselected(opt)

   return opt == self.state

end


function GUI.Radio:getnextoption(dir)

    local j = dir > 0 and #self.optarray or 1

    for i = self.state + dir, j, dir do

        if self.optarray[i] ~= "_" then
            return i
        end

    end

    return self.state

end




------------------------------------
-------- Checklist methods ---------
------------------------------------


GUI.Checklist = {}
setmetatable(GUI.Checklist, {__index = Option})

function GUI.Checklist:new(name, z, x, y, w, h, caption, opts, dir, pad)

    local checklist = Option:new(name, z, x, y, w, h, caption, opts, dir, pad)

    checklist.type = "Checklist"

    checklist.optsel = {}

    setmetatable(checklist, self)
    self.__index = self
    return checklist

end


function GUI.Checklist:initoptions()

	local size = self.opt_size

	-- Option bubble
	GUI.color("elm_frame")
	gfx.rect(1, 1, size, size, 0)
    gfx.rect(size + 3, 1, size, size, 0)

	GUI.color(self.col_fill)
	gfx.rect(size + 3 + 0.25*size, 1 + 0.25*size, 0.5*size, 0.5*size, 1)

end


function GUI.Checklist:val(newval)

	if newval ~= nil then
		if type(newval) == "table" then
			for k, v in pairs(newval) do
				self.optsel[tonumber(k)] = v
			end
			self:onchange()
			self:redraw()
        elseif type(newval) == "boolean" and #self.optarray == 1 then

            self.optsel[1] = newval
            self:onchange()
            self:redraw()
		end
	else
        if #self.optarray == 1 then
            return self.optsel[1]
        else
            local tmp = {}
            for i = 1, #self.optarray do
                tmp[i] = not not self.optsel[i]
            end
            return tmp
        end
		--return #self.optarray > 1 and self.optsel or self.optsel[1]
	end

end


function GUI.Checklist:onmouseup()

    -- Bypass option for GUI Builder
    if not self.focus then
        self:redraw()
        return
    end

    local mouseopt = self:getmouseopt()

    if not mouseopt then return end

	self.optsel[mouseopt] = not self.optsel[mouseopt]

    self.focus = false
	self:onchange()
	self:redraw()

end


function GUI.Checklist:isoptselected(opt)

   return self.optsel[opt]

end
-- NoIndex: true

--[[	Lokasenna_GUI (Team Audio addition) - SideNav class

    Creation parameters:
    name, z, x, y, tab_w, tab_h, opts[, pad_outer][, pad_inner]

]]--

if not GUI then
    reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
    missing_lib = true
    return 0
end

GUI.SideNav = GUI.Element:new()
function GUI.SideNav:new(name, z, x, y, tab_w, tab_h, opts, pad_outer, pad_inner)

    local SideNav = (not x and type(z) == "table") and z or {}

    SideNav.name = name
    SideNav.type = "SideNav"

    SideNav.z = SideNav.z or z

    SideNav.x = SideNav.x or x
    SideNav.y = SideNav.y or y
    SideNav.tab_w = SideNav.tab_w or tab_w or 200
    SideNav.tab_h = SideNav.tab_h or tab_h or 36

    SideNav.font_a = SideNav.font_a or 3
    SideNav.font_b = SideNav.font_b or 4

    SideNav.bg = SideNav.bg or "elm_bg"
    SideNav.col_txt = SideNav.col_txt or "txt"
    SideNav.col_tab_a = SideNav.col_tab_a or "wnd_bg"
    SideNav.col_tab_b = SideNav.col_tab_b or "elm_bg"
    SideNav.col_active = SideNav.col_active or "elm_fill"

    SideNav.pad_outer = SideNav.pad_outer or pad_outer or 16
    SideNav.pad_inner = SideNav.pad_inner or pad_inner or 4

    -- Parse the string of options into a table
    if not SideNav.optarray then
        local opts = SideNav.opts or opts

        SideNav.optarray = {}
        if type(opts) == "string" then
            for word in string.gmatch(opts, '([^,]+)') do
                SideNav.optarray[#SideNav.optarray + 1] = word
            end
        elseif type(opts) == "table" then
            SideNav.optarray = opts
        end
    end

    SideNav.z_sets = {}
    for i = 1, #SideNav.optarray do
        SideNav.z_sets[i] = {}
    end

    -- Figure out the total size of the SideNav frame now that we know the
    -- number of buttons, so we can do the math for clicking on it
    SideNav.w = SideNav.tab_w + 2 * SideNav.pad_outer
    SideNav.h = (SideNav.tab_h + SideNav.pad_inner) * #SideNav.optarray - SideNav.pad_inner + 2 * SideNav.pad_outer

    if SideNav.fullheight == nil then
        SideNav.fullheight = true
    end

    -- Currently-selected option
    SideNav.retval = SideNav.retval or 1
    SideNav.state = SideNav.retval or 1

    -- Index of the last mouse hover and mouse down event
    SideNav.hover_at = nil
    SideNav.down_at = nil

    GUI.redraw_z[SideNav.z] = true

    setmetatable(SideNav, self)
    self.__index = self
    return SideNav

end


function GUI.SideNav:init()

    self:update_sets()

end


function GUI.SideNav:draw()

    local x, y = self.x, self.y
    local tab_w, tab_h = self.tab_w, self.tab_h
    local pad_outer = self.pad_outer
    local pad_inner = self.pad_inner
    local state = self.state
    local hover_at = self.hover_at

    -- Make sure h is at least the size of the tabs.
    self.h = self.fullheight and (GUI.cur_h - self.y) or math.max(self.h, (tab_h + pad_inner) * #self.optarray - pad_inner + 2 * pad_outer)

    GUI.color(self.bg)
    gfx.rect(x, y, self.w, self.h, true)
    gfx.muladdrect(self.w - 1, y, 1, self.h, 0, 0, 0, GUI.colors["shadow"][4])

    local tab_x = x + pad_outer
    local tab_y = y + pad_outer

    for i = 1, #self.optarray do
        local active = i == state
        local hover = i == hover_at
        local col_tab = self.col_tab_b
        local font = self.font_b

        if active or hover then
            col_tab = self.col_tab_a
            font = self.font_a
        end

        self:draw_tab(tab_x, tab_y, tab_w, tab_h, font, self.col_txt, col_tab, self.optarray[i])

        if active then
            GUI.color(self.col_active)
            GUI.roundrect(tab_x, tab_y + 10, 4, tab_h - 20, 2, 1, 1)
        end

        tab_y = tab_y + tab_h + pad_inner
    end

end


-- Returns the index into optarray corresponding to the current mouse
-- position, or nil if the mouse is not over an item
function GUI.SideNav:mouse_at()

    local tab_x = self.x + self.pad_outer
    local tab_y = self.y + self.pad_outer

    for i = 1, #self.optarray do
        if GUI.IsInside({
            x = tab_x,
            y = tab_y,
            w = self.tab_w,
            h = self.tab_h
        }) then
            return i
        end
        tab_y = tab_y + self.tab_h + self.pad_inner
    end

    return nil

end


function GUI.SideNav:val(newval)

    if newval then
        self.state = newval
        self.retval = self.state

        self:update_sets()
        self:onchange()
        self:redraw()
    else
        return self.state
    end

end


function GUI.SideNav:onresize()

    if self.fullheight then self:redraw() end

end


------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.SideNav:onmousedown()

    self.down_at = self:mouse_at()
    self:redraw()

end


function GUI.SideNav:onmouseup()

    if self.down_at ~= nil and self.down_at == self:mouse_at() then
        self.state = self.down_at
        self.retval = self.state
        self:update_sets()
        self:onchange()
    end

    self.down_at = nil
    self:redraw()

end

function GUI.SideNav:onupdate()

    local prev_hover_at = self.hover_at
    self.hover_at = self:mouse_at()

    if self.hover_at ~= prev_hover_at then
        self:redraw()
    end

end




------------------------------------
-------- Drawing helpers -----------
------------------------------------


function GUI.SideNav:draw_tab(x, y, w, h, font, col_txt, col_bg, lbl)

    GUI.color(col_bg)

    GUI.roundrect(x, y, w, h, 4, 1, 1)

    -- Draw the tab's label
    GUI.color(col_txt)
    GUI.font(font)

    local str_w, str_h = gfx.measurestr(lbl)
    gfx.x = x + 18
    gfx.y = y + ((h - str_h) / 2)
    gfx.drawstr(lbl)

end




------------------------------------
-------- SideNav helpers -----------
------------------------------------


-- Updates visibility for any layers assigned to the tabs
function GUI.SideNav:update_sets(init)

    local state = self.state

    if init then
        self.z_sets = init
    end

    local z_sets = self.z_sets

    if not z_sets or #z_sets[1] < 1 then
        --reaper.ShowMessageBox("GUI element '"..self.name.."':\nNo z sets found.", "Library error", 0)
        --GUI.quit = true
        return 0
    end

    for i = 1, #z_sets do

        if i ~= state then
            for _, z in pairs(z_sets[i]) do

                GUI.elms_hide[z] = true

            end
        end

    end

    for _, z in pairs(z_sets[state]) do

        GUI.elms_hide[z] = false

    end

end
-- NoIndex: true

--[[	Lokasenna_GUI - Slider class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Slider

    Creation parameters:
  name, z, x, y, w, caption, min, max, defaults[, inc, dir, size]

]]--


if not GUI then
  reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
  missing_lib = true
  return 0
end

GUI.Slider = GUI.Element:new()

function GUI.Slider:new(name, z, x, y, w, caption, min, max, defaults, inc, dir, size)

  local Slider = (not x and type(z) == "table") and z or {}

  Slider.name = name
  Slider.type = "Slider"

  Slider.z = Slider.z or z

  Slider.x = Slider.x or x
    Slider.y = Slider.y or y

  Slider.dir = Slider.dir or dir or "h"
  Slider.size = Slider.size or size or 8

    Slider.w, Slider.h = table.unpack(Slider.dir ~= "v"
                        and {Slider.w or w, Slider.size}
                        or  {Slider.size, Slider.w or w} )

  Slider.caption = Slider.caption or caption
  Slider.bg = Slider.bg or "wnd_bg"

  Slider.font_a = Slider.font_a or 3
  Slider.font_b = Slider.font_b or 4

  Slider.col_txt = Slider.col_txt or "txt"
  Slider.col_hnd = Slider.col_hnd or "elm_frame"
  Slider.col_fill = Slider.col_fill or "elm_fill"

  if Slider.show_handles == nil then
      Slider.show_handles = true
  end
  if Slider.show_values == nil then
      Slider.show_values = true
  end

  Slider.cap_x = Slider.cap_x or 0
  Slider.cap_y = Slider.cap_y or 0

  local min = Slider.min or min
  local max = Slider.max or max

  if min > max then
      min, max = max, min
  elseif min == max then
      max = max + 1
  end

  if Slider.dir == "v" then
    min, max = max, min
  end

  Slider.align_values = Slider.align_values or 0

  Slider.min, Slider.max = min, max
  Slider.inc = Slider.inc or inc or 1

  function Slider:formatretval(val)

      local decimal = tonumber(string.match(val, "%.(.*)") or 0)
      local places = decimal ~= 0 and string.len( decimal) or 0
      return string.format("%." .. places .. "f", val)

  end

  Slider.defaults = Slider.defaults or defaults

  -- If the user only asked for one handle
  if type(Slider.defaults) == "number" then Slider.defaults = {Slider.defaults} end

  function Slider:init_handles()

    self.steps = math.abs(self.max - self.min) / self.inc

      -- Make sure the handles are all valid
      for i = 1, #self.defaults do
          self.defaults[i] = math.floor( GUI.clamp(0, tonumber(self.defaults[i]), self.steps) )
      end

      self.handles = {}
      local step
      for i = 1, #self.defaults do

          step = self.defaults[i]

          self.handles[i] = {}
          self.handles[i].default = (self.dir ~= "v" and step or (self.steps - step))
          self.handles[i].curstep = step
          self.handles[i].curval = step / self.steps
          self.handles[i].retval = self:formatretval( ((self.max - self.min) / self.steps)
                                                      * step + self.min)

      end

  end

  Slider:init_handles(defaults)

  GUI.redraw_z[Slider.z] = true

  setmetatable(Slider, self)
  self.__index = self
  return Slider

end


function GUI.Slider:init()

  self.buffs = self.buffs or GUI.GetBuffer(2)

    -- In case we were given a new set of handles without involving GUI.Val
    if not self.handles[1].default then self:init_handles() end

    local w, h = self.w, self.h

    -- Track
    gfx.dest = self.buffs[1]
    gfx.setimgdim(self.buffs[1], -1, -1)
    gfx.setimgdim(self.buffs[1], w + 4, h + 4)

  GUI.color("elm_bg")
  GUI.roundrect(2, 2, w, h, 4, 1, 1)
  GUI.color("elm_outline")
  GUI.roundrect(2, 2, w, h, 4, 1, 0)


    -- Handle
  local hw, hh = table.unpack(self.dir == "h" and {self.size, self.size * 2} or {self.size * 2, self.size})

  gfx.dest = self.buffs[2]
  gfx.setimgdim(self.buffs[2], -1, -1)
  gfx.setimgdim(self.buffs[2], 2 * hw + 4, hh + 2)

  GUI.color(self.col_hnd)
  GUI.roundrect(1, 1, hw, hh, 2, 1, 1)
  GUI.color("elm_outline")
  GUI.roundrect(1, 1, hw, hh, 2, 1, 0)

  local r, g, b, a = table.unpack(GUI.colors["shadow"])
  gfx.set(r, g, b, 1)
  GUI.roundrect(hw + 2, 1, hw, hh, 2, 1, 1)
  gfx.muladdrect(hw + 2, 1, hw + 2, hh + 2, 1, 1, 1, a, 0, 0, 0, 0 )

end


function GUI.Slider:ondelete()

  GUI.FreeBuffer(self.buffs)

end


function GUI.Slider:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h

  -- Draw track
    gfx.blit(self.buffs[1], 1, 0, 1, 1, w + 2, h + 2, x - 1, y - 1)

    -- To avoid a LOT of copy/pasting for vertical sliders, we can
    -- just swap x-y and w-h to effectively "rotate" all of the math
    -- 90 degrees. 'horz' is here to help out in a few situations where
    -- the values need to be swapped back for drawing stuff.

    self. horz = self.dir ~= "v"
    if not self.horz then x, y, w, h = y, x, h, w end

    -- Limit everything to be drawn within the square part of the track
    x, w = x + 4, w - 8

    -- Size of the handle
    self.handle_w, self.handle_h = self.size, h * 2
    local inc = w / self.steps
    local handle_y = y + (h - self.handle_h) / 2

    -- Get the handles' coordinates and the ends of the fill bar
    local min, max = self:updatehandlecoords(x, handle_y, inc)

    self:drawfill(x, y, h, min, max, inc)

    self:drawsliders()
    if self.caption and self.caption ~= "" then self:drawcaption() end

end


function GUI.Slider:val(newvals)

  if newvals then

    if type(newvals) == "number" then newvals = {newvals} end

    for i = 1, #self.handles do

            self:setcurstep(i, newvals[i])

    end

    self:redraw()

  else

    local ret = {}
    for i = 1, #self.handles do
      --[[
      table.insert(ret, (self.dir ~= "v" 	and (self.handles[i].curstep + self.min)
                        or	(self.steps - self.handles[i].curstep)))
      ]]--
            table.insert(ret, tonumber(self.handles[i].retval))

    end

    if #ret == 1 then
      return ret[1]
    else
      table.sort(ret)
      return ret
    end

  end

end




------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Slider:onmousedown()

  -- Snap the nearest slider to the nearest value

  local mouse_val = self.dir == "h"
          and (GUI.mouse.x - self.x) / self.w
          or  (GUI.mouse.y - self.y) / self.h

    self.cur_handle = self:getnearesthandle(mouse_val)

  self:setcurval(self.cur_handle, GUI.clamp(mouse_val, 0, 1) )

  self:redraw()

end


function GUI.Slider:ondrag()

  local mouse_val, n, ln = table.unpack(self.dir == "h"
          and {(GUI.mouse.x - self.x) / self.w, GUI.mouse.x, GUI.mouse.lx}
          or  {(GUI.mouse.y - self.y) / self.h, GUI.mouse.y, GUI.mouse.ly}
  )

  local cur = self.cur_handle or 1

  -- Ctrl?
  local ctrl = GUI.mouse.cap&4==4

  -- A multiplier for how fast the slider should move. Higher values = slower
  --						Ctrl							Normal
  local adj = ctrl and math.max(1200, (8*self.steps)) or 150
  local adj_scale = (self.dir == "h" and self.w or self.h) / 150
  adj = adj * adj_scale

    self:setcurval(cur, GUI.clamp( self.handles[cur].curval + ((n - ln) / adj) , 0, 1 ) )

  self:redraw()

end


function GUI.Slider:onwheel()

  local mouse_val = self.dir == "h"
          and (GUI.mouse.x - self.x) / self.w
          or  (GUI.mouse.y - self.y) / self.h

  local inc = GUI.round( self.dir == "h" and GUI.mouse.inc
                      or -GUI.mouse.inc )

    local cur = self:getnearesthandle(mouse_val)

  local ctrl = GUI.mouse.cap&4==4

  -- How many steps per wheel-step
  local fine = 1
  local coarse = math.max( GUI.round(self.steps / 30), 1)

  local adj = ctrl and fine or coarse

    self:setcurval(cur, GUI.clamp( self.handles[cur].curval + (inc * adj / self.steps) , 0, 1) )

  self:redraw()

end


function GUI.Slider:ondoubleclick()

    -- Ctrl+click - Only reset the closest slider to the mouse
  if GUI.mouse.cap & 4 == 4 then

    local mouse_val = (GUI.mouse.x - self.x) / self.w
    local small_diff, small_idx
    for i = 1, #self.handles do

      local diff = math.abs( self.handles[i].curval - mouse_val )
      if not small_diff or diff < small_diff then
        small_diff = diff
        small_idx = i
      end

    end

        self:setcurstep(small_idx, self.handles[small_idx].default)

    -- Reset all sliders
  else

    for i = 1, #self.handles do

            self:setcurstep(i, self.handles[i].default)

    end

  end

  self:redraw()

end




------------------------------------
-------- Drawing helpers -----------
------------------------------------


function GUI.Slider:updatehandlecoords(x, handle_y, inc)

    local min, max

    for i = 1, #self.handles do

        local center = x + inc * self.handles[i].curstep
        self.handles[i].x, self.handles[i].y = center - (self.handle_w / 2), handle_y

        if not min or center < min then min = center end
        if not max or center > max then max = center end

    end

    return min, max

end


function GUI.Slider:drawfill(x, y, h, min, max, inc)

    -- Get the color
  if (#self.handles > 1)
    or self.handles[1].curstep ~= self.handles[1].default then

        self:setfill()

    end

    -- Cap for the fill bar
    if #self.handles == 1 then
        min = x + inc * self.handles[1].default

        _ = self.horz and gfx.circle(min, y + (h / 2), h / 2 - 1, 1, 1)
                      or  gfx.circle(y + (h / 2), min, h / 2 - 1, 1, 1)

    end

    if min > max then min, max = max, min end

    _ = self.horz and gfx.rect(min, y + 1, max - min, h - 1, 1)
                  or  gfx.rect(y + 1, min, h - 1, max - min, 1)

end


function GUI.Slider:setfill()

    -- If the user has given us two colors to make a gradient with
    if self.col_fill_a and #self.handles == 1 then

        -- Make a gradient,
        local col_a = GUI.colors[self.col_fill_a]
        local col_b = GUI.colors[self.col_fill_b]
        local grad_step = self.handles[1].curstep / self.steps

        local r, g, b, a = GUI.gradient(col_a, col_b, grad_step)

        gfx.set(r, g, b, a)

    else
        GUI.color(self.col_fill)
    end

end


function GUI.Slider:drawsliders()

    GUI.color(self.col_txt)
    GUI.font(self.font_b)

    -- Drawing them in reverse order so overlaps match the shadow direction
    for i = #self.handles, 1, -1 do

        local handle_x, handle_y = GUI.round(self.handles[i].x) - 1, GUI.round(self.handles[i].y) - 1

        if self.show_values then

            local x = handle_x
            local y = self.y + self.h + self.h

            if self.horz then
                self:drawslidervalue(handle_x + self.handle_w/2, handle_y + self.handle_h + 4, i)
            else
                self:drawslidervalue(handle_y + self.handle_h + self.handle_h, handle_x, i)
            end

        end

        if self.show_handles then

            if self.horz then
                self:drawsliderhandle(handle_x, handle_y, self.handle_w, self.handle_h)
            else
                self:drawsliderhandle(handle_y, handle_x, self.handle_h, self.handle_w)
            end

        end

    end

end


function GUI.Slider:drawslidervalue(x, y, sldr)

    local output = self.handles[sldr].retval

    if self.output then
        local t = type(self.output)

        if t == "string" or t == "number" then
            output = self.output
        elseif t == "table" then
            output = self.output[output]
        elseif t == "function" then
            output = self.output(output)
        end
    end

    gfx.x, gfx.y = x, y

    GUI.text_bg(output, self.bg, self.align_values + 256)
    gfx.drawstr(output, self.align_values + 256, gfx.x, gfx.y)

end


function GUI.Slider:drawsliderhandle(hx, hy, hw, hh)

    for j = 1, GUI.shadow_dist do

        gfx.blit(self.buffs[2], 1, 0, hw + 2, 0, hw + 2, hh + 2, hx + j, hy + j)

    end

    --gfx.blit(source, scale, rotation[, srcx, srcy, srcw, srch, destx, desty, destw, desth, rotxoffs, rotyoffs] )

    gfx.blit(self.buffs[2], 1, 0, 0, 0, hw + 2, hh + 2, hx, hy)

end


function GUI.Slider:drawcaption()

  GUI.font(self.font_a)

  local str_w, str_h = gfx.measurestr(self.caption)

  gfx.x = self.x + (self.w - str_w) / 2 + self.cap_x
  gfx.y = self.y - (self.dir ~= "v" and self.h or self.w) - str_h + self.cap_y
  GUI.text_bg(self.caption, self.bg)
  GUI.shadow(self.caption, self.col_txt, "shadow")

end




------------------------------------
-------- Slider helpers ------------
------------------------------------


function GUI.Slider:getnearesthandle(val)

  local small_diff, small_idx

  for i = 1, #self.handles do

    local diff = math.abs( self.handles[i].curval - val )

    if not small_diff or (diff < small_diff) then
      small_diff = diff
      small_idx = i

    end

  end

    return small_idx

end


function GUI.Slider:setcurstep(sldr, step)

    self.handles[sldr].curstep = step
    self.handles[sldr].curval = self.handles[sldr].curstep / self.steps
    self:setretval(sldr)


end


function GUI.Slider:setcurval(sldr, val)

    self.handles[sldr].curval = val
    self.handles[sldr].curstep = GUI.round(val * self.steps)
    self:setretval(sldr)

end


function GUI.Slider:setretval(sldr)

    local val = self.dir == "h" and self.inc * self.handles[sldr].curstep + self.min
                                or self.min - self.inc * self.handles[sldr].curstep

    self.handles[sldr].retval = self:formatretval(val)
    self:onchange()

end
-- NoIndex: true

--[[	Lokasenna_GUI - Tabs class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Tabs

    Creation parameters:
    name, z, x, y, tab_w, tab_h, opts[, pad]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end

GUI.Tabs = GUI.Element:new()
function GUI.Tabs:new(name, z, x, y, tab_w, tab_h, opts, pad)

	local Tab = (not x and type(z) == "table") and z or {}

	Tab.name = name
	Tab.type = "Tabs"

	Tab.z = Tab.z or z

	Tab.x = Tab.x or x
    Tab.y = Tab.y or y
	Tab.tab_w = Tab.tab_w or tab_w or 48
    Tab.tab_h = Tab.tab_h or tab_h or 20

	Tab.font_a = Tab.font_a or 3
    Tab.font_b = Tab.font_b or 4

	Tab.bg = Tab.bg or "elm_bg"
	Tab.col_txt = Tab.col_txt or "txt"
	Tab.col_tab_a = Tab.col_tab_a or "wnd_bg"
	Tab.col_tab_b = Tab.col_tab_b or "tab_bg"

    -- Placeholder for if I ever figure out downward tabs
	Tab.dir = Tab.dir or "u"

	Tab.pad = Tab.pad or pad or 8

	-- Parse the string of options into a table
    if not Tab.optarray then
        local opts = Tab.opts or opts

        Tab.optarray = {}
        if type(opts) == "string" then
            for word in string.gmatch(opts, '([^,]+)') do
                Tab.optarray[#Tab.optarray + 1] = word
            end
        elseif type(opts) == "table" then
            Tab.optarray = opts
        end
    end

	Tab.z_sets = {}
	for i = 1, #Tab.optarray do
		Tab.z_sets[i] = {}
	end

	-- Figure out the total size of the Tab frame now that we know the
    -- number of buttons, so we can do the math for clicking on it
	Tab.w, Tab.h = (Tab.tab_w + Tab.pad) * #Tab.optarray + 2*Tab.pad + 12, Tab.tab_h

    if Tab.fullwidth == nil then
        Tab.fullwidth = true
    end

	-- Currently-selected option
	Tab.retval = Tab.retval or 1
    Tab.state = Tab.retval or 1

	GUI.redraw_z[Tab.z] = true

	setmetatable(Tab, self)
	self.__index = self
	return Tab

end


function GUI.Tabs:init()

    self:update_sets()

end


function GUI.Tabs:draw()

	local x, y = self.x + 16, self.y
    local tab_w, tab_h = self.tab_w, self.tab_h
	local pad = self.pad
	local font = self.font_b
	local dir = self.dir
	local state = self.state

    -- Make sure w is at least the size of the tabs.
    -- (GUI builder will let you try to set it lower)
    self.w = self.fullwidth and (GUI.cur_w - self.x) or math.max(self.w, (tab_w + pad) * #self.optarray + 2*pad + 12)

	GUI.color(self.bg)
	gfx.rect(x - 16, y, self.w, self.h, true)

	local x_adj = tab_w + pad

	-- Draw the inactive tabs first
	for i = #self.optarray, 1, -1 do

		if i ~= state then
			--
			local tab_x, tab_y = x + GUI.shadow_dist + (i - 1) * x_adj,
								 y + GUI.shadow_dist * (dir == "u" and 1 or -1)

			self:draw_tab(tab_x, tab_y, tab_w, tab_h, dir, font, self.col_txt, self.col_tab_b, self.optarray[i])

		end

	end

	self:draw_tab(x + (state - 1) * x_adj, y, tab_w, tab_h, dir, self.font_a, self.col_txt, self.col_tab_a, self.optarray[state])

    -- Keep the active tab's top separate from the window background
	GUI.color(self.bg)
    gfx.line(x + (state - 1) * x_adj, y, x + state * x_adj, y, 1)

	-- Cover up some ugliness at the bottom of the tabs
	GUI.color("wnd_bg")
	gfx.rect(self.x, self.y + (dir == "u" and tab_h or -6), self.w, 6, true)


end


function GUI.Tabs:val(newval)

	if newval then
		self.state = newval
		self.retval = self.state

		self:update_sets()
		self:onchange()
		self:redraw()
	else
		return self.state
	end

end


function GUI.Tabs:onresize()

    if self.fullwidth then self:redraw() end

end


------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Tabs:onmousedown()

    -- Offset for the first tab
	local adj = 0.75*self.h

	local mouseopt = (GUI.mouse.x - (self.x + adj)) / (#self.optarray * (self.tab_w + self.pad))

	mouseopt = GUI.clamp((math.floor(mouseopt * #self.optarray) + 1), 1, #self.optarray)

	self.state = mouseopt

	self:redraw()

end


function GUI.Tabs:onmouseup()

	-- Set the new option, or revert to the original if the cursor isn't inside the list anymore
	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then

		self.retval = self.state
		self:update_sets()
		self:onchange()

	else
		self.state = self.retval
	end

	self:redraw()

end


function GUI.Tabs:ondrag()

	self:onmousedown()
	self:redraw()

end


function GUI.Tabs:onwheel()

	self.state = GUI.round(self.state + GUI.mouse.inc)

	if self.state < 1 then self.state = 1 end
	if self.state > #self.optarray then self.state = #self.optarray end

	self.retval = self.state
	self:update_sets()
	self:onchange()
	self:redraw()

end




------------------------------------
-------- Drawing helpers -----------
------------------------------------


function GUI.Tabs:draw_tab(x, y, w, h, dir, font, col_txt, col_bg, lbl)

	local dist = GUI.shadow_dist
    local y1, y2 = table.unpack(dir == "u" and  {y, y + h}
                                           or   {y + h, y})

	GUI.color("shadow")

    -- Tab shadow
    for i = 1, dist do

        gfx.rect(x + i, y, w, h, true)

        gfx.triangle(   x + i, y1,
                        x + i, y2,
                        x + i - (h / 2), y2)

        gfx.triangle(   x + i + w, y1,
                        x + i + w, y2,
                        x + i + w + (h / 2), y2)

    end

    -- Hide those gross, pixellated edges
    gfx.line(x + dist, y1, x + dist - (h / 2), y2, 1)
    gfx.line(x + dist + w, y1, x + dist + w + (h / 2), y2, 1)

    GUI.color(col_bg)

    gfx.rect(x, y, w, h, true)

    gfx.triangle(   x, y1,
                    x, y2,
                    x - (h / 2), y2)

    gfx.triangle(   x + w, y1,
                    x + w, y2,
                    x + w + (h / 2), y + h)

    gfx.line(x, y1, x - (h / 2), y2, 1)
    gfx.line(x + w, y1, x + w + (h / 2), y2, 1)


	-- Draw the tab's label
	GUI.color(col_txt)
	GUI.font(font)

	local str_w, str_h = gfx.measurestr(lbl)
	gfx.x = x + ((w - str_w) / 2)
	gfx.y = y + ((h - str_h) / 2)
	gfx.drawstr(lbl)

end




------------------------------------
-------- Tab helpers ---------------
------------------------------------


-- Updates visibility for any layers assigned to the tabs
function GUI.Tabs:update_sets(init)

	local state = self.state

	if init then
		self.z_sets = init
	end

	local z_sets = self.z_sets

	if not z_sets or #z_sets[1] < 1 then
		--reaper.ShowMessageBox("GUI element '"..self.name.."':\nNo z sets found.", "Library error", 0)
		--GUI.quit = true
		return 0
	end

	for i = 1, #z_sets do

        if i ~= state then
            for _, z in pairs(z_sets[i]) do

                GUI.elms_hide[z] = true

            end
        end

	end

    for _, z in pairs(z_sets[state]) do

        GUI.elms_hide[z] = false

    end

end
-- NoIndex: true

--[[	Lokasenna_GUI - Textbox class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Textbox

    Creation parameters:
	name, z, x, y, w, h[, caption, pad]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


GUI.Textbox = GUI.Element:new()
function GUI.Textbox:new(name, z, x, y, w, h, caption, pad)

	local txt = (not x and type(z) == "table") and z or {}

	txt.name = name
	txt.type = "Textbox"

	txt.z = txt.z or z

	txt.x = txt.x or x
    txt.y = txt.y or y
    txt.w = txt.w or w
    txt.h = txt.h or h

    txt.retval = txt.retval or ""

	txt.caption = txt.caption or caption or ""
	txt.pad = txt.pad or pad or 4

    if txt.shadow == nil then
        txt.shadow = true
    end
	txt.bg = txt.bg or "wnd_bg"
	txt.color = txt.color or "txt"

	txt.font_a = txt.font_a or 3

	txt.font_b = txt.font_b or "monospace"

    txt.cap_pos = txt.cap_pos or "left"

    txt.undo_limit = txt.undo_limit or 20

    txt.undo_states = {}
    txt.redo_states = {}

    txt.wnd_pos = 0
	txt.caret = 0
	txt.sel_s, txt.sel_e = nil, nil

    txt.char_h, txt.wnd_h, txt.wnd_w, txt.char_w = nil, nil, nil, nil

	txt.focus = false

	txt.blink = 0

	GUI.redraw_z[txt.z] = true

	setmetatable(txt, self)
	self.__index = self
	return txt

end


function GUI.Textbox:init()

	local x, y, w, h = self.x, self.y, self.w, self.h

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*w, h)

	GUI.color("elm_bg")
	gfx.rect(0, 0, 2*w, h, 1)

	GUI.color("elm_frame")
	gfx.rect(0, 0, w, h, 0)

	GUI.color("elm_fill")
	gfx.rect(w, 0, w, h, 0)
	gfx.rect(w + 1, 1, w - 2, h - 2, 0)

    -- Make sure we calculate this ASAP to avoid errors with
    -- dynamically-generated textboxes
    if gfx.w > 0 then self:wnd_recalc() end

end


function GUI.Textbox:ondelete()

	GUI.FreeBuffer(self.buff)

end


function GUI.Textbox:draw()

	-- Some values can't be set in :init() because the window isn't
	-- open yet - measurements won't work.
	if not self.wnd_w then self:wnd_recalc() end

	if self.caption and self.caption ~= "" then self:drawcaption() end

	-- Blit the textbox frame, and make it brighter if focused.
	gfx.blit(self.buff, 1, 0, (self.focus and self.w or 0), 0,
            self.w, self.h, self.x, self.y)

    self:drawtext()

	if self.focus then

		if self.sel_s then self:drawselection() end
		if self.show_caret then self:drawcaret() end

	end

    self:drawgradient()

end


function GUI.Textbox:val(newval)

	if newval then
        self:seteditorstate(tostring(newval))
		self:redraw()
	else
		return self.retval
	end

end


-- Just for making the caret blink
function GUI.Textbox:onupdate()

	if self.focus then

		if self.blink == 0 then
			self.show_caret = true
			self:redraw()
		elseif self.blink == math.floor(GUI.txt_blink_rate / 2) then
			self.show_caret = false
			self:redraw()
		end
		self.blink = (self.blink + 1) % GUI.txt_blink_rate

	end

end

-- Make sure the box highlight goes away
function GUI.Textbox:lostfocus()

    self:redraw()

end



------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Textbox:onmousedown()

    self.caret = self:getcaret(GUI.mouse.x)

    -- Reset the caret so the visual change isn't laggy
    self.blink = 0

    -- Shift+click to select text
    if GUI.mouse.cap & 8 == 8 and self.caret then

        self.sel_s, self.sel_e = self.caret, self.caret

    else

        self.sel_s, self.sel_e = nil, nil

    end

    self:redraw()

end


function GUI.Textbox:ondoubleclick()

	self:selectword()

end


function GUI.Textbox:ondrag()

	self.sel_s = self:getcaret(GUI.mouse.ox, GUI.mouse.oy)
    self.sel_e = self:getcaret(GUI.mouse.x, GUI.mouse.y)

	self:redraw()

end


function GUI.Textbox:ontype()

	local char = GUI.char

    -- Navigation keys, Return, clipboard stuff, etc
    if self.keys[char] then

        local shift = GUI.mouse.cap & 8 == 8

        if shift and not self.sel_s then
            self.sel_s = self.caret
        end

        -- Flag for some keys (clipboard shortcuts) to skip
        -- the next section
        local bypass = self.keys[char](self)

        if shift and char ~= GUI.chars.BACKSPACE then

            self.sel_e = self.caret

        elseif not bypass then

            self.sel_s, self.sel_e = nil, nil

        end

    -- Typeable chars
    elseif GUI.clamp(32, char, 254) == char then

        if self.sel_s then self:deleteselection() end

        self:insertchar(char)

    end
    self:windowtocaret()

    -- Make sure no functions crash because they got a type==number
    self.retval = tostring(self.retval)

    -- Reset the caret so the visual change isn't laggy
    self.blink = 0

end


function GUI.Textbox:onwheel(inc)

   local len = string.len(self.retval)

   if len <= self.wnd_w then return end

   -- Scroll right/left
   local dir = inc > 0 and 3 or -3
   self.wnd_pos = GUI.clamp(0, self.wnd_pos + dir, len + 2 - self.wnd_w)

   self:redraw()

end




------------------------------------
-------- Drawing methods -----------
------------------------------------


function GUI.Textbox:drawcaption()

    local caption = self.caption

    GUI.font(self.font_a)

    local str_w, str_h = gfx.measurestr(caption)

    if self.cap_pos == "left" then
        gfx.x = self.x - str_w - self.pad
        gfx.y = self.y + (self.h - str_h) / 2

    elseif self.cap_pos == "top" then
        gfx.x = self.x + (self.w - str_w) / 2
        gfx.y = self.y - str_h - self.pad

    elseif self.cap_pos == "topleft" then
        gfx.x = self.x
        gfx.y = self.y - str_h - self.pad

    elseif self.cap_pos == "right" then
        gfx.x = self.x + self.w + self.pad
        gfx.y = self.y + (self.h - str_h) / 2

    elseif self.cap_pos == "bottom" then
        gfx.x = self.x + (self.w - str_w) / 2
        gfx.y = self.y + self.h + self.pad

    end

    GUI.text_bg(caption, self.bg)

    if self.shadow then
        GUI.shadow(caption, self.color, "shadow")
    else
        GUI.color(self.color)
        gfx.drawstr(caption)
    end

end


function GUI.Textbox:drawtext()

    local str = self.retval
    if str == "" then
        if self.placeholder then
            str = self.placeholder
            GUI.color("elm_fill")
            GUI.font(self.font_a)
        else
            return
        end
    else
        GUI.color(self.color)
        GUI.font(self.font_b)
    end
    str = string.sub(str, self.wnd_pos + 1)

    -- I don't think self.pad should affect the text at all. Looks weird,
    -- messes with the amount of visible text too much.
	gfx.x = self.x + 4 -- + self.pad
	gfx.y = self.y + (self.h - gfx.texth) / 2
    local r = gfx.x + self.w - 8 -- - 2*self.pad
    local b = gfx.y + gfx.texth

	gfx.drawstr(str, 0, r, b)

end


function GUI.Textbox:drawcaret()

    local caret_wnd = self:adjusttowindow(self.caret)

    if caret_wnd then

        GUI.color("txt")

        local caret_h = self.char_h - 2

        gfx.rect(   self.x + (caret_wnd * self.char_w) + 4,
                    self.y + (self.h - caret_h) / 2,
                    self.insert_caret and self.char_w or 2,
                    caret_h)

    end

end


function GUI.Textbox:drawselection()

    local x, w

    GUI.color("elm_fill")
    gfx.a = 0.5
    gfx.mode = 1

    local s, e = self.sel_s, self.sel_e

    if e < s then s, e = e, s end


    local x = GUI.clamp(self.wnd_pos, s, self:wnd_right())
    local w = GUI.clamp(x, e, self:wnd_right()) - x

    if self:selectionvisible(x, w) then

        -- Convert from char-based coords to actual pixels
        x = self.x + (x - self.wnd_pos) * self.char_w + 4

        h = self.char_h - 2

        y = self.y + (self.h - h) / 2

        w = w * self.char_w
        w = math.min(w, self.x + self.w - x - self.pad)



        gfx.rect(x, y, w, h, true)

    end

    gfx.mode = 0

	-- Later calls to GUI.color should handle this, but for
	-- some reason they aren't always.
    gfx.a = 1

end


function GUI.Textbox:drawgradient()

    local left, right = self.wnd_pos > 0, self.wnd_pos < (string.len(self.retval) - self.wnd_w + 2)
    if not (left or right) then return end

    local x, y, w, h = self.x, self.y, self.w, self.h
    local fade_w = 8

    GUI.color("elm_bg")
    for i = 0, fade_w do

        gfx.a = i/fade_w

        -- Left
        if left then
            local x = x + 2 + fade_w - i
            gfx.line(x, y + 2, x, y + h - 4)
        end

        -- Right
        if right then
            local x = x + w - 3 - fade_w + i
            gfx.line(x, y + 2, x, y + h - 4)
        end

    end

end




------------------------------------
-------- Selection methods ---------
------------------------------------


-- Make sure at least part of the selection is visible
function GUI.Textbox:selectionvisible(x, w)

	return 		w > 0                   -- Selection has width,
			and x + w > self.wnd_pos    -- doesn't end to the left
            and x < self:wnd_right()    -- and doesn't start to the right

end


function GUI.Textbox:selectall()

    self.sel_s = 0
    self.caret = 0
    self.sel_e = string.len(self.retval)

end


function GUI.Textbox:selectword()

    local str = self.retval

    if not str or str == "" then return 0 end

    self.sel_s = string.find( str:sub(1, self.caret), "%s[%S]+$") or 0
    self.sel_e = (      string.find( str, "%s", self.sel_s + 1)
                    or  string.len(str) + 1)
                - (self.wnd_pos > 0 and 2 or 1) -- Kludge, fixes length issues

end


function GUI.Textbox:deleteselection()

    if not (self.sel_s and self.sel_e) then return 0 end

    self:storeundostate()

    local s, e = self.sel_s, self.sel_e

    if s > e then
        s, e = e, s
    end

    self.retval =   string.sub(self.retval or "", 1, s)..
                    string.sub(self.retval or "", e + 1)

    self.caret = s

    self.sel_s, self.sel_e = nil, nil
    self:windowtocaret()
    self:onchange()

end


function GUI.Textbox:getselectedtext()

    local s, e= self.sel_s, self.sel_e

    if s > e then s, e = e, s end

    return string.sub(self.retval, s + 1, e)

end


function GUI.Textbox:toclipboard(cut)

    if self.sel_s and self:SWS_clipboard() then

        local str = self:getselectedtext()
        reaper.CF_SetClipboard(str)
        if cut then self:deleteselection() end

    end

end


function GUI.Textbox:fromclipboard()

    if self:SWS_clipboard() then

        -- reaper.SNM_CreateFastString( str )
        -- reaper.CF_GetClipboardBig( output )
        local fast_str = reaper.SNM_CreateFastString("")
        local str = reaper.CF_GetClipboardBig(fast_str)
        reaper.SNM_DeleteFastString(fast_str)

        self:insertstring(str, true)

    end

end



------------------------------------
-------- Window/pos helpers --------
------------------------------------


function GUI.Textbox:wnd_recalc()

    GUI.font(self.font_b)

    --[[
    self.char_h = gfx.texth
    self.char_w = gfx.measurestr("_")
    ]]--
    self.char_w, self.char_h = gfx.measurestr("i")
    self.wnd_w = math.floor(self.w / self.char_w)

end


function GUI.Textbox:wnd_right()

   return self.wnd_pos + self.wnd_w

end


-- See if a given position is in the visible window
-- If so, adjust it from absolute to window-relative
-- If not, returns nil
function GUI.Textbox:adjusttowindow(x)

    return ( GUI.clamp(self.wnd_pos, x, self:wnd_right() - 1) == x )
        and x - self.wnd_pos
        or nil

end


function GUI.Textbox:windowtocaret()

    if self.caret < self.wnd_pos + 1 then
        self.wnd_pos = math.max(0, self.caret - 1)
    elseif self.caret > (self:wnd_right() - 2) then
        self.wnd_pos = self.caret + 2 - self.wnd_w
    end

end


function GUI.Textbox:getcaret(x)

    x = math.floor(  ((x - self.x) / self.w) * self.wnd_w) + self.wnd_pos
    return GUI.clamp(0, x, string.len(self.retval or ""))

end




------------------------------------
-------- Char/string helpers -------
------------------------------------


function GUI.Textbox:insertstring(str, move_caret)

    self:storeundostate()

    str = self:sanitizetext(str)

    if self.sel_s then self:deleteselection() end

    local s = self.caret

    local pre, post =   string.sub(self.retval or "", 1, s),
                        string.sub(self.retval or "", s + 1)

    self.retval = pre .. tostring(str) .. post

    if move_caret then self.caret = self.caret + string.len(str) end

    self:onchange()

end


function GUI.Textbox:insertchar(char)

    self:storeundostate()

    local a, b = string.sub(self.retval, 1, self.caret),
                 string.sub(self.retval, self.caret + (self.insert_caret and 2 or 1))

    self.retval = a..string.char(char)..b
    self.caret = self.caret + 1

    self:onchange()

end


function GUI.Textbox:carettoend()

   return string.len(self.retval or "")

end


-- Replace any characters that we're unable to reproduce properly
function GUI.Textbox:sanitizetext(str)

    str = tostring(str)
    str = str:gsub("\t", "    ")
    str = str:gsub("[\n\r]", " ")
    return str

end


function GUI.Textbox:ctrlchar(func, ...)

    if GUI.mouse.cap & 4 == 4 then
        func(self, ... and table.unpack({...}))

        -- Flag to bypass the "clear selection" logic in :ontype()
        return true

    else
        self:insertchar(GUI.char)
    end

end

-- Non-typing key commands
-- A table of functions is more efficient to access than using really
-- long if/then/else structures.
GUI.Textbox.keys = {

    [GUI.chars.LEFT] = function(self)

        self.caret = math.max( 0, self.caret - 1)

    end,

    [GUI.chars.RIGHT] = function(self)

        self.caret = math.min( string.len(self.retval), self.caret + 1 )

    end,

    [GUI.chars.UP] = function(self)

        self.caret = 0

    end,

    [GUI.chars.DOWN] = function(self)

        self.caret = string.len(self.retval)

    end,

    [GUI.chars.BACKSPACE] = function(self)

        self:storeundostate()

        if self.sel_s then

            self:deleteselection()

        else

        if self.caret <= 0 then return end

            local str = self.retval
            self.retval =   string.sub(str, 1, self.caret - 1)..
                            string.sub(str, self.caret + 1, -1)
            self.caret = math.max(0, self.caret - 1)
            self:onchange()

        end

    end,

    [GUI.chars.INSERT] = function(self)

        self.insert_caret = not self.insert_caret

    end,

    [GUI.chars.DELETE] = function(self)

        self:storeundostate()

        if self.sel_s then

            self:deleteselection()

        else

            local str = self.retval
            self.retval =   string.sub(str, 1, self.caret) ..
                            string.sub(str, self.caret + 2)
            self:onchange()

        end

    end,

    [GUI.chars.RETURN] = function(self)

        self.focus = false
        self:lostfocus()
        self:redraw()

    end,

    [GUI.chars.HOME] = function(self)

        self.caret = 0

    end,

    [GUI.chars.END] = function(self)

        self.caret = string.len(self.retval)

    end,

    [GUI.chars.TAB] = function(self)

        GUI.tab_to_next(self)

    end,

	-- A -- Select All
	[1] = function(self)

		return self:ctrlchar(self.selectall)

	end,

	-- C -- Copy
	[3] = function(self)

		return self:ctrlchar(self.toclipboard)

	end,

	-- V -- Paste
	[22] = function(self)

        return self:ctrlchar(self.fromclipboard)

	end,

	-- X -- Cut
	[24] = function(self)

		return self:ctrlchar(self.toclipboard, true)

	end,

	-- Y -- Redo
	[25] = function (self)

		return self:ctrlchar(self.redo)

	end,

	-- Z -- Undo
	[26] = function (self)

		return self:ctrlchar(self.undo)

	end


}




------------------------------------
-------- Misc. helpers -------------
------------------------------------


function GUI.Textbox:undo()

	if #self.undo_states == 0 then return end
	table.insert(self.redo_states, self:geteditorstate() )
	local state = table.remove(self.undo_states)

    self.retval = state.retval
	self.caret = state.caret

	self:windowtocaret()
	self:onchange()

end


function GUI.Textbox:redo()

	if #self.redo_states == 0 then return end
	table.insert(self.undo_states, self:geteditorstate() )
	local state = table.remove(self.redo_states)

	self.retval = state.retval
	self.caret = state.caret

	self:windowtocaret()
	self:onchange()

end


function GUI.Textbox:storeundostate()

table.insert(self.undo_states, self:geteditorstate() )
	if #self.undo_states > self.undo_limit then table.remove(self.undo_states, 1) end
	self.redo_states = {}

end


function GUI.Textbox:geteditorstate()

	return { retval = self.retval, caret = self.caret }

end


function GUI.Textbox:seteditorstate(retval, caret, wnd_pos, sel_s, sel_e)

    self.retval = retval or ""
    self.caret = math.min(caret and caret or self.caret, string.len(self.retval))
    self.wnd_pos = wnd_pos or 0
    self.sel_s, self.sel_e = sel_s or nil, sel_e or nil
    self:onchange()

end



-- See if we have a new-enough version of SWS for the clipboard functions
-- (v2.9.7 or greater)
function GUI.Textbox:SWS_clipboard()

	if GUI.SWS_exists then
		return true
	else

		reaper.ShowMessageBox(	"Clipboard functions require the SWS extension, v2.9.7 or newer."..
									"\n\nDownload the latest version at http://www.sws-extension.org/index.php",
									"Sorry!", 0)
		return false

	end

end
-- NoIndex: true

--[[	Lokasenna_GUI - TextEditor class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/TextEditor

    Creation parameters:
	name, z, x, y, w, h[, text, caption, pad, disableEditing]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


GUI.TextEditor = GUI.Element:new()
function GUI.TextEditor:new(name, z, x, y, w, h, text, caption, pad, disableEditing)

	local txt = (not x and type(z) == "table") and z or {}

	txt.name = name
	txt.type = "TextEditor"

	txt.z = txt.z or z

	txt.x = txt.x or x
    txt.y = txt.y or y
    txt.w = txt.w or w
    txt.h = txt.h or h

	txt.retval = txt.retval or text or {}

	txt.caption = txt.caption or caption or ""
	txt.pad = txt.pad or pad or 4
	txt.disableEditing = txt.disableEditing or disableEditing

    if txt.shadow == nil then
        txt.shadow = true
    end
	txt.bg = txt.bg or "elm_bg"
    txt.cap_bg = txt.cap_bg or "wnd_bg"
	txt.color = txt.color or "txt"

	-- Scrollbar fill
	txt.col_fill = txt.col_fill or "elm_fill"

	txt.font_a = txt.font_a or 3

	-- Forcing a safe monospace font to make our lives easier
	txt.font_b = txt.font_bg or "monospace"

	txt.wnd_pos = {x = 0, y = 1}
	txt.caret = {x = 0, y = 1}

	txt.char_h, txt.wnd_h, txt.wnd_w, txt.char_w = nil, nil, nil, nil

	txt.focus = false

	txt.undo_limit = 20
	txt.undo_states = {}
	txt.redo_states = {}

	txt.blink = 0

	GUI.redraw_z[txt.z] = true

	setmetatable(txt, self)
	self.__index = self
	return txt

end


function GUI.TextEditor:init()

	-- Process the initial string; split it into a table by line
	if type(self.retval) == "string" then self:val(self.retval) end

	local x, y, w, h = self.x, self.y, self.w, self.h

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*w, h)

	GUI.color(self.bg)
	gfx.rect(0, 0, 2*w, h, 1)

	GUI.color("elm_frame")
	gfx.rect(0, 0, w, h, 0)

	GUI.color("elm_fill")
	gfx.rect(w, 0, w, h, 0)
	gfx.rect(w + 1, 1, w - 2, h - 2, 0)


end


function GUI.TextEditor:ondelete()

	GUI.FreeBuffer(self.buff)

end


function GUI.TextEditor:draw()

	-- Some values can't be set in :init() because the window isn't
	-- open yet - measurements won't work.
	if not self.wnd_h then self:wnd_recalc() end

	-- Draw the caption
	if self.caption and self.caption ~= "" then self:drawcaption() end

	-- Draw the background + frame
	gfx.blit(self.buff, 1, 0, (self.focus and self.w or 0), 0,
            self.w, self.h, self.x, self.y)

	-- Draw the text
	self:drawtext()

	-- Caret
	-- Only needs to be drawn for half of the blink cycle
	if self.focus then
       --[[
        --Draw line highlight a la NP++ ??
        GUI.color("elm_bg")
        gfx.a = 0.2
        gfx.mode = 1


        gfx.mode = 0
        gfx.a = 1
       ]]--

        -- Selection
        if self.sel_s and self.sel_e then

            self:drawselection()

        end

        if self.show_caret then self:drawcaret() end

    end


	-- Scrollbars
	self:drawscrollbars()

end


function GUI.TextEditor:val(newval)

	if newval then
		self:seteditorstate(
            type(newval) == "table" and newval
                                    or self:stringtotable(newval))
		self:redraw()
	else
		return table.concat(self.retval, "\n")
	end

end


function GUI.TextEditor:onupdate()

	if self.focus then

		if self.blink == 0 then
			self.show_caret = true
			self:redraw()
		elseif self.blink == math.floor(GUI.txt_blink_rate / 2) then
			self.show_caret = false
			self:redraw()
		end
		self.blink = (self.blink + 1) % GUI.txt_blink_rate

	end

end


function GUI.TextEditor:lostfocus()

	self:redraw()

end




-----------------------------------
-------- Input methods ------------
-----------------------------------


function GUI.TextEditor:onmousedown()

	-- If over the scrollbar, or we came from :ondrag with an origin point
	-- that was over the scrollbar...
	local scroll = self:overscrollbar()
	if scroll then

        self:setscrollbar(scroll)

    else

        -- Place the caret
        self.caret = self:getcaret(GUI.mouse.x, GUI.mouse.y)

        -- Reset the caret so the visual change isn't laggy
        self.blink = 0

        -- Shift+click to select text
        if GUI.mouse.cap & 8 == 8 and self.caret then

                self.sel_s = {x = self.caret.x, y = self.caret.y}
                self.sel_e = {x = self.caret.x, y = self.caret.y}

        else

            self:clearselection()

        end

    end

    self:redraw()

end


function GUI.TextEditor:ondoubleclick()

	self:selectword()

end


function GUI.TextEditor:ondrag()

	local scroll = self:overscrollbar(GUI.mouse.ox, GUI.mouse.oy)
	if scroll then

        self:setscrollbar(scroll)

	-- Select from where the mouse is now to where it started
	else

		self.sel_s = self:getcaret(GUI.mouse.ox, GUI.mouse.oy)
		self.sel_e = self:getcaret(GUI.mouse.x, GUI.mouse.y)

	end

	self:redraw()

end


function GUI.TextEditor:ontype(char, mod)

    local char = char or GUI.char
    local mod = mod or GUI.mouse.cap

	-- Non-typeable / navigation chars
	if self.keys[char] then

		local shift = mod & 8 == 8

		if shift and not self.sel_s then
			self.sel_s = {x = self.caret.x, y = self.caret.y}
		end

		-- Flag for some keys (clipboard shortcuts) to skip
		-- the next section
        local bypass = self.keys[char](self)

		if shift and char ~= GUI.chars.BACKSPACE and char ~= GUI.chars.TAB then

			self.sel_e = {x = self.caret.x, y = self.caret.y}

		elseif not bypass then

			self:clearselection()

		end

	-- Typeable chars
	elseif not self.disableEditing and GUI.clamp(32, char, 254) == char then

		if self.sel_s then self:deleteselection() end

		self:insertchar(char)
        -- Why are we doing this when the selection was just deleted?
		--self:clearselection()


	end
	self:windowtocaret()

	-- Reset the caret so the visual change isn't laggy
	self.blink = 0

end


function GUI.TextEditor:onwheel(inc)

	-- Ctrl -- maybe zoom?
	if GUI.mouse.cap & 4 == 4 then

		--[[ Buggy, disabled for now
		local font = self.font_b
		font = 	(type(font) == "string" and GUI.fonts[font])
			or	(type(font) == "table" and font)

		if not font then return end

		local dir = inc > 0 and 4 or -4

		font[2] = GUI.clamp(8, font[2] + dir, 30)

		self.font_b = font

		self:wnd_recalc()
		]]--

	-- Shift -- Horizontal scroll
	elseif GUI.mouse.cap & 8 == 8 then

		local len = self:getmaxlength()

		if len <= self.wnd_w then return end

		-- Scroll right/left
		local dir = inc > 0 and 3 or -3
		self.wnd_pos.x = GUI.clamp(0, self.wnd_pos.x + dir, len - self.wnd_w + 4)

	-- Vertical scroll
	else

		local len = self:getwndlength()

		if len <= self.wnd_h then return end

		-- Scroll up/down
		local dir = inc > 0 and -3 or 3
		self.wnd_pos.y = GUI.clamp(1, self.wnd_pos.y + dir, len - self.wnd_h + 1)

	end

	self:redraw()

end




------------------------------------
-------- Drawing methods -----------
------------------------------------


function GUI.TextEditor:drawcaption()

	local str = self.caption

	GUI.font(self.font_a)
	local str_w, str_h = gfx.measurestr(str)
	gfx.x = self.x - str_w - self.pad
	gfx.y = self.y + self.pad
	GUI.text_bg(str, self.cap_bg)

	if self.shadow then
		GUI.shadow(str, self.color, "shadow")
	else
		GUI.color(self.color)
		gfx.drawstr(str)
	end

end


function GUI.TextEditor:drawtext()

	GUI.color(self.color)
	GUI.font(self.font_b)

	local tmp = {}
	for i = self.wnd_pos.y, math.min(self:wnd_bottom() - 1, #self.retval) do

		local str = tostring(self.retval[i]) or ""
		tmp[#tmp + 1] = string.sub(str, self.wnd_pos.x + 1, self:wnd_right() - 1)

	end

	gfx.x, gfx.y = self.x + self.pad, self.y + self.pad
	gfx.drawstr( table.concat(tmp, "\n") )

end


function GUI.TextEditor:drawcaret()

	local caret_wnd = self:adjusttowindow(self.caret)

	if caret_wnd.x and caret_wnd.y then

		GUI.color("txt")

		gfx.rect(	self.x + self.pad + (caret_wnd.x * self.char_w),
					self.y + self.pad + (caret_wnd.y * self.char_h),
					self.insert_caret and self.char_w or 2,
					self.char_h - 2)

	end

end


function GUI.TextEditor:drawselection()

	local off_x, off_y = self.x + self.pad, self.y + self.pad
	local x, y, w, h

	GUI.color("elm_fill")
	gfx.a = 0.5
	gfx.mode = 1

	-- Get all the selection boxes that need to be drawn
	local coords = self:getselection()

	for i = 1, #coords do

		-- Make sure at least part of this line is visible
		if self:selectionvisible(coords[i]) then

			-- Convert from char/row coords to actual pixels
			x, y =	off_x + (coords[i].x - self.wnd_pos.x) * self.char_w,
					off_y + (coords[i].y - self.wnd_pos.y) * self.char_h

									-- Really kludgy, but it fixes a weird issue
									-- where wnd_pos.x > 0 was drawing all the widths
									-- one character too short
			w =		(coords[i].w + (self.wnd_pos.x > 0 and 1 or 0)) * self.char_w

			-- Keep the selection from spilling out past the scrollbar
            -- ***recheck this, the self.x doesn't make sense***
			w = math.min(w, self.x + self.w - x - self.pad)

			h =	self.char_h

			gfx.rect(x, y, w, h, true)

		end

	end

	gfx.mode = 0

	-- Later calls to GUI.color should handle this, but for
	-- some reason they aren't always.
	gfx.a = 1

end


function GUI.TextEditor:drawscrollbars()

	-- Do we need to be here?
	local max_w, txt_h = self:getmaxlength(), self:getwndlength()
	local vert, horz = 	txt_h > self.wnd_h,
						max_w > self.wnd_w


	local x, y, w, h = self.x, self.y, self.w, self.h
	local vx, vy, vw, vh = x + w - 8 - 4, y + 4, 8, h - 16
	local hx, hy, hw, hh = x + 4, y + h - 8 - 4, w - 16, 8
	local fade_w = 12
	local _

    -- Only draw the empty tracks if we don't need scroll bars
	if not (vert or horz) then goto tracks end

	-- Draw a gradient to fade out the last ~16px of text
	GUI.color("elm_bg")
	for i = 0, fade_w do

		gfx.a = i/fade_w

		if vert then

			gfx.line(vx + i - fade_w, y + 2, vx + i - fade_w, y + h - 4)

			-- Fade out the top if we're not at wnd_pos.y = 1
			_ = self.wnd_pos.y > 1 and
				gfx.line(x + 2, y + 2 + fade_w - i, x + w - 4, y + 2 + fade_w - i)

		end

		if horz then

			gfx.line(x + 2, hy + i - fade_w, x + w - 4, hy + i - fade_w)

			-- Fade out the left if we're not at wnd_pos.x = 0
			_ = self.wnd_pos.x > 0 and
				gfx.line(x + 2 + fade_w - i, y + 2, x + 2 + fade_w - i, y + h - 4)

		end

	end

	_ = vert and gfx.rect(vx, y + 2, vw + 2, h - 4, true)
	_ = horz and gfx.rect(x + 2, hy, w - 4, hh + 2, true)


    ::tracks::

	-- Draw slider track
	GUI.color("tab_bg")
	GUI.roundrect(vx, vy, vw, vh, 4, 1, 1)
	GUI.roundrect(hx, hy, hw, hh, 4, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(vx, vy, vw, vh, 4, 1, 0)
	GUI.roundrect(hx, hy, hw, hh, 4, 1, 0)


	-- Draw slider fill
	GUI.color(self.col_fill)

	if vert then
		local fh = (self.wnd_h / txt_h) * vh - 4
		if fh < 4 then fh = 4 end
		local fy = vy + ((self.wnd_pos.y - 1) / txt_h) * vh + 2

		GUI.roundrect(vx + 2, fy, vw - 4, fh, 2, 1, 1)
	end

	if horz then
		local fw = (self.wnd_w / (max_w + 4)) * hw - 4
		if fw < 4 then fw = 4 end
		local fx = hx + (self.wnd_pos.x / (max_w + 4)) * hw + 2

		GUI.roundrect(fx, hy + 2, fw, hh - 4, 2, 1, 1)
	end

end




------------------------------------
-------- Selection methods ---------
------------------------------------


function GUI.TextEditor:getselectioncoords()

	local sx, sy = self.sel_s.x, self.sel_s.y
	local ex, ey = self.sel_e.x, self.sel_e.y

	-- Make sure the Start is before the End
	if sy > ey then
		sx, sy, ex, ey = ex, ey, sx, sy
	elseif sy == ey and sx > ex then
		sx, ex = ex, sx
	end

    return sx, sy, ex, ey

end


-- Figure out what portions of the text are selected
function GUI.TextEditor:getselection()

    local sx, sy, ex, ey = self:getselectioncoords()

	local x, w
	local sel_coords = {}

	local function insert_coords(x, y, w)
		table.insert(sel_coords, {x = x, y = y, w = w})
	end

	-- Eliminate the easiest case - start and end are the same line
	if sy == ey then

		x = GUI.clamp(self.wnd_pos.x, sx, self:wnd_right())
		w = GUI.clamp(x, ex, self:wnd_right()) - x

		insert_coords(x, sy, w)


	-- ...fine, we'll do it the hard way
	else

		-- Start
		x = GUI.clamp(self.wnd_pos.x, sx, self:wnd_right())
		w = math.min(self:wnd_right(), #(self.retval[sy] or "")) - x

		insert_coords(x, sy, w)


		-- Any intermediate lines are clearly full
		for i = self.wnd_pos.y, self:wnd_bottom() - 1 do

			x, w = nil, nil

			-- Is this line within the selection?
			if i > sy and i < ey then

				w = math.min(self:wnd_right(), #(self.retval[i] or "")) - self.wnd_pos.x
				insert_coords(self.wnd_pos.x, i, w)

			-- We're past the selection
			elseif i >= ey then

				break

			end

		end


		-- End
		x = self.wnd_pos.x
		w = math.min(self:wnd_right(), ex) - self.wnd_pos.x
		insert_coords(x, ey, w)


	end

	return sel_coords


end


-- Make sure at least part of this selection block is within the window
function GUI.TextEditor:selectionvisible(coords)

	return 		coords.w > 0                            -- Selection has width,
			and coords.x + coords.w > self.wnd_pos.x    -- doesn't end to the left
            and coords.x < self:wnd_right()             -- doesn't start to the right
			and coords.y >= self.wnd_pos.y              -- and is on a visible line
			and coords.y < self:wnd_bottom()

end


function GUI.TextEditor:selectall()

	self.sel_s = {x = 0, y = 1}
	self.caret = {x = 0, y = 1}
	self.sel_e = {	x = string.len(self.retval[#self.retval]),
					y = #self.retval}


end


function GUI.TextEditor:selectword()

	local str = self.retval[self.caret.y] or ""

	if not str or str == "" then return 0 end

	local sx = string.find( str:sub(1, self.caret.x), "%s[%S]+$") or 0

	local ex =	(	string.find( str, "%s", sx + 1)
			or		string.len(str) + 1 )
				- (self.wnd_pos.x > 0 and 2 or 1)	-- Kludge, fixes length issues

	self.sel_s = {x = sx, y = self.caret.y}
	self.sel_e = {x = ex, y = self.caret.y}

end


function GUI.TextEditor:clearselection()

	self.sel_s, self.sel_e = nil, nil

end


function GUI.TextEditor:deleteselection()

	if not (self.sel_s and self.sel_e) then return 0 end

	self:storeundostate()

    local sx, sy, ex, ey = self:getselectioncoords()

	-- Easiest case; single line
	if sy == ey then

		self.retval[sy] =   string.sub(self.retval[sy] or "", 1, sx)..
                            string.sub(self.retval[sy] or "", ex + 1)

	else

		self.retval[sy] =   string.sub(self.retval[sy] or "", 1, sx)..
                            string.sub(self.retval[ey] or "", ex + 1)
		for i = sy + 1, ey do
			table.remove(self.retval, sy + 1)
		end

	end

	self.caret.x, self.caret.y = sx, sy

	self:clearselection()
	self:windowtocaret()
	self:onchange()

end


function GUI.TextEditor:getselectedtext()

    local sx, sy, ex, ey = self:getselectioncoords()

	local tmp = {}

	for i = 0, ey - sy do

		tmp[i + 1] = self.retval[sy + i]

	end

	tmp[1] = string.sub(tmp[1], sx + 1)
	tmp[#tmp] = string.sub(tmp[#tmp], 1, ex - (sy == ey and sx or 0))

	return table.concat(tmp, "\n")

end


function GUI.TextEditor:toclipboard(cut)

    if self.sel_s and self:SWS_clipboard() then

        local str = self:getselectedtext()
        reaper.CF_SetClipboard(str)
        if cut then self:deleteselection() end

    end

end


function GUI.TextEditor:fromclipboard()

    if self:SWS_clipboard() then

        -- reaper.SNM_CreateFastString( str )
        -- reaper.CF_GetClipboardBig( output )
        local fast_str = reaper.SNM_CreateFastString("")
        local str = reaper.CF_GetClipboardBig(fast_str)
        reaper.SNM_DeleteFastString(fast_str)

        self:insertstring(str, true)

    end

end

------------------------------------
-------- Window/Pos Helpers --------
------------------------------------


-- Updates internal values for the window size
function GUI.TextEditor:wnd_recalc()

	GUI.font(self.font_b)
	self.char_w, self.char_h = gfx.measurestr("i")
	self.wnd_h = math.floor((self.h - 2*self.pad) / self.char_h)
	self.wnd_w = math.floor(self.w / self.char_w)

end


-- Get the right edge of the window (in chars)
function GUI.TextEditor:wnd_right()

	return self.wnd_pos.x + self.wnd_w

end


-- Get the bottom edge of the window (in rows)
function GUI.TextEditor:wnd_bottom()

	return self.wnd_pos.y + self.wnd_h

end


-- Get the length of the longest line
function GUI.TextEditor:getmaxlength()

	local w = 0

	-- Slightly faster because we don't care about order
	for k, v in pairs(self.retval) do
		w = math.max(w, string.len(v))
	end

	-- Pad the window out a little
	return w + 2

end


-- Add 2 to the table length so the horizontal scrollbar isn't in the way
function GUI.TextEditor:getwndlength()

	return #self.retval + 2

end


-- See if a given pair of coords is in the visible window
-- If so, adjust them from absolute to window-relative
-- If not, returns nil
function GUI.TextEditor:adjusttowindow(coords)

	local x, y = coords.x, coords.y
	x = (GUI.clamp(self.wnd_pos.x, x, self:wnd_right() - 3) == x)
						and x - self.wnd_pos.x
						or nil

	-- Fixes an issue with the position being one space to the left of where it should be
	-- when the window isn't at x = 0. Not sure why.
	--x = x and (x + (self.wnd_pos.x == 0 and 0 or 1))

	y = (GUI.clamp(self.wnd_pos.y, y, self:wnd_bottom() - 1) == y)
						and y - self.wnd_pos.y
						or nil

	return {x = x, y = y}

end


-- Adjust the window if the caret has been moved off-screen
function GUI.TextEditor:windowtocaret()

	-- Horizontal
	if self.caret.x < self.wnd_pos.x + 4 then
		self.wnd_pos.x = math.max(0, self.caret.x - 4)
	elseif self.caret.x > (self:wnd_right() - 4) then
		self.wnd_pos.x = self.caret.x + 4 - self.wnd_w
	end

	-- Vertical
	local bot = self:wnd_bottom()
	local adj = (	(self.caret.y < self.wnd_pos.y) and -1	)
			or	(	(self.caret.y >= bot) and 1	)
			or	(	(bot > self:getwndlength() and -(bot - self:getwndlength() - 1) ) )

	if adj then self.wnd_pos.y = GUI.clamp(1, self.wnd_pos.y + adj, self.caret.y) end

end


-- TextEditor - Get the closest character position to the given coords.
function GUI.TextEditor:getcaret(x, y)

	local tmp = {}

	tmp.x = math.floor(		((x - self.x) / self.w ) * self.wnd_w)
                            + self.wnd_pos.x
	tmp.y = math.floor(		(y - (self.y + self.pad))
						/	self.char_h)
			+ self.wnd_pos.y

	tmp.y = GUI.clamp(1, tmp.y, #self.retval)
	tmp.x = GUI.clamp(0, tmp.x, #(self.retval[tmp.y] or ""))

	return tmp

end


-- Is the mouse over either of the scrollbars?
-- Returns "h", "v", or false
function GUI.TextEditor:overscrollbar(x, y)

	if	self:getwndlength() > self.wnd_h
	and (x or GUI.mouse.x) >= (self.x + self.w - 12) then

		return "v"

	elseif 	self:getmaxlength() > self.wnd_w
	and		(y or GUI.mouse.y) >= (self.y + self.h - 12) then

		return "h"

	end

end


function GUI.TextEditor:setscrollbar(scroll)

    -- Vertical scroll
    if scroll == "v" then

        local len = self:getwndlength()
        local wnd_c = GUI.round( ((GUI.mouse.y - self.y) / self.h) * len  )
        self.wnd_pos.y = GUI.round(
                            GUI.clamp(	1,
                                        wnd_c - (self.wnd_h / 2),
                                        len - self.wnd_h + 1
                                    )
                                    )

    -- Horizontal scroll
    else
    --self.caret.x + 4 - self.wnd_w

        local len = self:getmaxlength()
        local wnd_c = GUI.round( ((GUI.mouse.x - self.x) / self.w) * len   )
        self.wnd_pos.x = GUI.round(
                            GUI.clamp(	0,
                                        wnd_c - (self.wnd_w / 2),
                                        len + 4 - self.wnd_w
                                    )
                                    )

    end


end




------------------------------------
-------- Char/String Helpers -------
------------------------------------


-- Split a string by line into a table
function GUI.TextEditor:stringtotable(str)

    str = self:sanitizetext(str)
	local pattern = "([^\r\n]*)\r?\n?"
	local tmp = {}
	for line in string.gmatch(str, pattern) do
		table.insert(tmp, line )
	end

	return tmp

end


-- Insert a string at the caret, deleting any existing selection
-- i.e. Paste
function GUI.TextEditor:insertstring(str, move_caret)

	self:storeundostate()

    str = self:sanitizetext(str)

	if self.sel_s then self:deleteselection() end

    local sx, sy = self.caret.x, self.caret.y

	local tmp = self:stringtotable(str)

	local pre, post =	string.sub(self.retval[sy] or "", 1, sx),
						string.sub(self.retval[sy] or "", sx + 1)

	if #tmp == 1 then

		self.retval[sy] = pre..tmp[1]..post
		if move_caret then self.caret.x = self.caret.x + #tmp[1] end

	else

		self.retval[sy] = tostring(pre)..tmp[1]
		table.insert(self.retval, sy + 1, tmp[#tmp]..tostring(post))

		-- Insert our paste lines backwards so sy+1 is always correct
		for i = #tmp - 1, 2, -1 do
			table.insert(self.retval, sy + 1, tmp[i])
		end

		if move_caret then
			self.caret = {	x =	string.len(tmp[#tmp]),
							y =	self.caret.y + #tmp - 1}
		end

	end

	self:onchange()

end


-- Insert typeable characters
function GUI.TextEditor:insertchar(char)

	self:storeundostate()

	local str = self.retval[self.caret.y] or ""

	local a, b = str:sub(1, self.caret.x),
                 str:sub(self.caret.x + (self.insert_caret and 2 or 1))
	self.retval[self.caret.y] = a..string.char(char)..b
	self.caret.x = self.caret.x + 1

	self:onchange()

end


-- Place the caret at the end of the current line
function GUI.TextEditor:carettoend()
	--[[
	return #(self.retval[self.caret.y] or "") > 0
		and #self.retval[self.caret.y]
		or 0
	]]--

    return string.len(self.retval[self.caret.y] or "")

end


-- Replace any characters that we're unable to reproduce properly
function GUI.TextEditor:sanitizetext(str)

    if type(str) == "string" then

        return str:gsub("\t", "    ")

    elseif type(str) == "table" then

        local tmp = {}
        for i = 1, #str do

            tmp[i] = str[i]:gsub("\t", "    ")

            return tmp

        end

    end

end


-- Backspace by up to four " " characters, if present.
function GUI.TextEditor:backtab()

    local str = self.retval[self.caret.y]
    local pre, post = string.sub(str, 1, self.caret.x), string.sub(str, self.caret.x + 1)

    local space
    pre, space = string.match(pre, "(.-)(%s*)$")

    pre = pre .. (space and string.sub(space, 1, -5) or "")

    self.caret.x = string.len(pre)
    self.retval[self.caret.y] = pre..post

    self:onchange()

end


function GUI.TextEditor:ctrlchar(func, ...)

    if GUI.mouse.cap & 4 == 4 then
        func(self, ... and table.unpack({...}))

        -- Flag to bypass the "clear selection" logic in :ontype()
        return true

    else
        self:insertchar(GUI.char)
    end

end


-- Non-typing key commands
-- A table of functions is more efficient to access than using really
-- long if/then/else structures.
GUI.TextEditor.keys = {

	[GUI.chars.LEFT] = function(self)

		if self.caret.x < 1 and self.caret.y > 1 then
			self.caret.y = self.caret.y - 1
			self.caret.x = self:carettoend()
		else
			self.caret.x = math.max(self.caret.x - 1, 0)
		end

	end,

	[GUI.chars.RIGHT] = function(self)

		if self.caret.x == self:carettoend() and self.caret.y < self:getwndlength() then
			self.caret.y = self.caret.y + 1
			self.caret.x = 0
		else
			self.caret.x = math.min(self.caret.x + 1, self:carettoend() )
		end

	end,

	[GUI.chars.UP] = function(self)

		if self.caret.y == 1 then
			self.caret.x = 0
		else
			self.caret.y = math.max(1, self.caret.y - 1)
			self.caret.x = math.min(self.caret.x, self:carettoend() )
		end

	end,

	[GUI.chars.DOWN] = function(self)

		if self.caret.y == self:getwndlength() then
			self.caret.x = string.len(self.retval[#self.retval])
		else
			self.caret.y = math.min(self.caret.y + 1, #self.retval)
			self.caret.x = math.min(self.caret.x, self:carettoend() )
		end

	end,

	[GUI.chars.HOME] = function(self)

		self.caret.x = 0

	end,

	[GUI.chars.END] = function(self)

		self.caret.x = self:carettoend()

	end,

	[GUI.chars.PGUP] = function(self)

		local caret_off = self.caret and (self.caret.y - self.wnd_pos.y)

		self.wnd_pos.y = math.max(1, self.wnd_pos.y - self.wnd_h)

		if caret_off then
			self.caret.y = self.wnd_pos.y + caret_off
			self.caret.x = math.min(self.caret.x, string.len(self.retval[self.caret.y]))
		end

	end,

	[GUI.chars.PGDN] = function(self)

		local caret_off = self.caret and (self.caret.y - self.wnd_pos.y)

		self.wnd_pos.y = GUI.clamp(1, self:getwndlength() - self.wnd_h + 1, self.wnd_pos.y + self.wnd_h)

		if caret_off then
			self.caret.y = self.wnd_pos.y + caret_off
			self.caret.x = math.min(self.caret.x, string.len(self.retval[self.caret.y]))
		end

	end,

	[GUI.chars.BACKSPACE] = function(self)

		self:storeundostate()

		-- Is there a selection?
		if self.sel_s and self.sel_e then

			self:deleteselection()

		-- If we have something to backspace, delete it
		elseif self.caret.x > 0 then

			local str = self.retval[self.caret.y]
			self.retval[self.caret.y] = str:sub(1, self.caret.x - 1)..
                                        str:sub(self.caret.x + 1, -1)
			self.caret.x = self.caret.x - 1
			self:onchange()

		-- Beginning of the line; backspace the contents to the prev. line
		elseif self.caret.x == 0 and self.caret.y > 1 then

			self.caret.x = #self.retval[self.caret.y - 1]
			self.retval[self.caret.y - 1] = self.retval[self.caret.y - 1] .. (self.retval[self.caret.y] or "")
			table.remove(self.retval, self.caret.y)
			self.caret.y = self.caret.y - 1
			self:onchange()

		end

	end,

	[GUI.chars.TAB] = function(self)

        -- Disabled until Reaper supports this properly
		--self:insertchar(9)

        if GUI.mouse.cap & 8 == 8 then
            self:backtab()
        else
            self:insertstring("    ", true)
		end

	end,

	[GUI.chars.INSERT] = function(self)

		self.insert_caret = not self.insert_caret

	end,

	[GUI.chars.DELETE] = function(self)

		self:storeundostate()

		-- Is there a selection?
		if self.sel_s then

			self:deleteselection()

		-- Deleting on the current line
		elseif self.caret.x < self:carettoend() then

			local str = self.retval[self.caret.y] or ""
			self.retval[self.caret.y] = str:sub(1, self.caret.x) ..
                                        str:sub(self.caret.x + 2)
			self:onchange()

		elseif self.caret.y < self:getwndlength() then

			self.retval[self.caret.y] = self.retval[self.caret.y] ..
                                        (self.retval[self.caret.y + 1] or "")
			table.remove(self.retval, self.caret.y + 1)
			self:onchange()

		end

	end,

	[GUI.chars.RETURN] = function(self)

		self:storeundostate()

		if sel_s then self:deleteselection() end

		local str = self.retval[self.caret.y] or ""
		self.retval[self.caret.y] = str:sub(1, self.caret.x)
		table.insert(self.retval, self.caret.y + 1, str:sub(self.caret.x + 1) )
		self.caret.y = self.caret.y + 1
		self.caret.x = 0
		self:onchange()

	end,

	-- A -- Select All
	[1] = function(self)

        return self:ctrlchar(self.selectall)
--[[
		if GUI.mouse.cap & 4 == 4 then

			self:selectall()

			-- Flag to bypass the "clear selection" logic in :ontype()
			return true

		else
			self:insertchar(GUI.char)
		end
]]--
	end,

	-- C -- Copy
	[3] = function(self)

		return self:ctrlchar(self.toclipboard)

	end,

	-- V -- Paste
	[22] = function(self)

		return self:ctrlchar(self.fromclipboard)

	end,

	-- X -- Cut
	[24] = function(self)

		return self:ctrlchar(self.toclipboard, true)

	end,

	-- Y -- Redo
	[25] = function (self)

		return self:ctrlchar(self.redo)

	end,

	-- Z -- Undo
	[26] = function (self)

		return self:ctrlchar(self.undo)

	end
}




------------------------------------
-------- Misc. Functions -----------
------------------------------------


function GUI.TextEditor:undo()

	if #self.undo_states == 0 then return end
	table.insert(self.redo_states, self:geteditorstate() )
	local state = table.remove(self.undo_states)

	self.retval = state.retval
	self.caret = state.caret

	self:windowtocaret()
	self:onchange()

end


function GUI.TextEditor:redo()

	if #self.redo_states == 0 then return end
	table.insert(self.undo_states, self:geteditorstate() )
	local state = table.remove(self.redo_states)
	self.retval = state.retval
	self.caret = state.caret

	self:windowtocaret()
	self:onchange()

end


function GUI.TextEditor:storeundostate()

	table.insert(self.undo_states, self:geteditorstate() )
	if #self.undo_states > self.undo_limit then table.remove(self.undo_states, 1) end
	self.redo_states = {}

end


function GUI.TextEditor:geteditorstate()

	local state = { retval = {} }
	for k,v in pairs(self.retval) do
		state.retval[k] = v
	end
	state.caret = {x = self.caret.x, y = self.caret.y}

	return state

end


function GUI.TextEditor:seteditorstate(retval, caret, wnd_pos, sel_s, sel_e)

    self.retval = retval or {""}
    self.wnd_pos = wnd_pos or {x = 0, y = 1}
	self.caret = caret or {x = 0, y = 1}
    self.sel_s = sel_s or nil
    self.sel_e = sel_e or nil
	self:onchange()

end



-- See if we have a new-enough version of SWS for the clipboard functions
-- (v2.9.7 or greater)
function GUI.TextEditor:SWS_clipboard()

	if GUI.SWS_exists then
		return true
	else

		reaper.ShowMessageBox(	"Clipboard functions require the SWS extension, v2.9.7 or newer."..
									"\n\nDownload the latest version at http://www.sws-extension.org/index.php",
									"Sorry!", 0)
		return false

	end

end

-- NoIndex: true

--[[	Lokasenna_GUI - Window class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Window

    Creation parameters:
	name, z, x, y, w, h, caption, z_set[, center]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


GUI.Window = GUI.Element:new()
function GUI.Window:new(name, z, x, y, w, h, caption, z_set, center) -- Add your own params here

	local wnd = (not x and type(z) == "table") and z or {}

	wnd.name = name
	wnd.type = "Window"

	wnd.z = wnd.z or z

	wnd.x = wnd.x or x
    wnd.y = wnd.y or y
    wnd.w = wnd.w or w
    wnd.h = wnd.h or h

    wnd.caption = wnd.caption or caption

    wnd.title_height = wnd.title_height or 20
    wnd.close_size = wnd.title_height - 8

    if wnd.center == nil then
        wnd.center = not center and true or center
    end

    wnd.noclose = wnd.noclose or false

    wnd.z_set = wnd.z_set or z_set
    wnd.noadjust = {}

	GUI.redraw_z[wnd.z] = true

	setmetatable(wnd, self)
	self.__index = self
	return wnd

end


function GUI.Window:init()

	local x, y, w, h = self.x, self.y, self.w, self.h

    -- buffs[3] will be filled at :open
	self.buffs = self.buffs or GUI.GetBuffer(3)

    local th, cs = self.title_height, self.close_size


    -- Window frame/background
	gfx.dest = self.buffs[1]
	gfx.setimgdim(self.buffs[1], -1, -1)
	gfx.setimgdim(self.buffs[1], w, h)

	GUI.color("elm_frame")
    --gfx.rect(0, 0, w, h, true)
    GUI.roundrect(0, 0, w - 2, h - 2, 4, true, true)

	GUI.color("wnd_bg")
	gfx.rect(4, th + 4, w - 10, h - (th + 10), true)



    -- [Close] button

    gfx.dest = self.buffs[2]
    gfx.setimgdim(self.buffs[2], -1, -1)
    gfx.setimgdim(self.buffs[2], 2*cs, cs)

    GUI.font(2)
    local str_w, str_h = gfx.measurestr("x")

    local function draw_x(x, y, w)

        gfx.line(x,     y,          x + w - 1,  y + w - 1,  false)
        gfx.line(x,     y + 1,      x + w - 2,  y + w - 1,  false)
        gfx.line(x + 1, y,          x + w - 1,  y + w - 2,  false)

        gfx.line(x,     y + w - 1,  x + w - 1,  y,      false)
        gfx.line(x,     y + w - 2,  x + w - 2,  y,      false)
        gfx.line(x + 1, y + w - 1,  x + w - 1,  y + 1,  false)

    end

    -- Background
    GUI.color("elm_frame")
    gfx.rect(0, 0, 2*cs, cs, true)

    GUI.color("txt")
    draw_x(2, 2, cs - 4)


    -- Mouseover circle
    GUI.color("elm_fill")
    GUI.roundrect(cs, 0, cs - 1, cs - 1, 4, true, true)

    GUI.color("wnd_bg")
    draw_x(cs + 2, 2, cs - 4)

end


function GUI.Window:ondelete()

    GUI.FreeBuffer(self.buffs)

end


function GUI.Window:onupdate()

    if GUI.escape_bypass == "close" then
        self:close()
        return
    end

    if self.hoverclose and not self:mouseoverclose() then
        self.hoverclose = nil
        self:redraw()
        return true
    end

end



function GUI.Window:draw()

    self:drawbackground()
    self:drawwindow()
    if self.caption and self.caption ~= "" then self:drawcaption() end


end




------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Window:onmouseup()

    if not self.noclose and self:mouseoverclose() then
        self:close()
        self:redraw()
    end

end


function GUI.Window:onmouseover()

    if self.noclose then return end

    local old = self.hoverclose
    self.hoverclose = self:mouseoverclose()

    if self.hoverclose ~= old then self:redraw() end

end




------------------------------------
-------- Drawing helpers -----------
------------------------------------


function GUI.Window:drawbackground()

    gfx.blit(self.buffs[3], 1, 0, 0, 0, GUI.cur_w, GUI.cur_h, 0, 0, GUI.cur_w, GUI.cur_h)

    GUI.color("shadow")
    gfx.a = 0.4
    gfx.rect(0, 0, GUI.cur_w, GUI.cur_h)
    gfx.a = 1

end


function GUI.Window:drawwindow()

	local x, y, w, h = self.x, self.y, self.w, self.h
    local cs = self.close_size
    local off = (self.title_height - cs) / 2 + 2

    -- Copy the pre-drawn bits
	gfx.blit(self.buffs[1], 1, 0, 0, 0, w, h, x, y)
    if not self.noclose then
        gfx.blit(self.buffs[2], 1, 0, self.hoverclose and cs or 0, 0, cs, cs, x + w - cs - off, y + off)
    end

end


function GUI.Window:drawcaption()

    GUI.font(2)
    GUI.color("txt")
    local str_w, str_h = gfx.measurestr(self.caption)
    gfx.x = self.x + (self.w - str_w) / 2
    gfx.y = self.y + (self.title_height - str_h) / 2 + 1 -- extra px looks better
    gfx.drawstr(self.caption)

end




------------------------------------
-------- Script methods ------------
------------------------------------


function GUI.Window:open(...)

    if self.center then self.x, self.y = GUI.center(self) end

    self:hidelayers()

    -- Flag for Core.lua so pressing Esc will close this window
    -- and not the script window
    GUI.escape_bypass = true

    -- Run user hook
    if self.onopen then self:onopen({...}) end

    self:blitwindow()

    self:redraw()

end


function GUI.Window:close(...)

    -- Run user hook
    if self.onclose then self:onclose({...}) end

    self:showlayers()

    GUI.escape_bypass = false

end


function GUI.Window:adjustelm(elm, force)

    if elm.ox and not force then return end

    elm.ox, elm.oy = elm.x, elm.y
    elm.x, elm.y = self.x + elm.x, self.y + self.title_height + elm.y

end


function GUI.Window:adjustchildelms(force)

    for k in pairs( self:getchildelms() ) do

        if not self.noadjust[k] then

            self:adjustelm(GUI.elms[k], force)

        end

    end

end


------------------------------------
-------- Helpers -------------------
------------------------------------


function GUI.Window:mouseoverclose()

    if GUI.IsInside(   {x = self.x + self.w - self.title_height - 4,
                        y = self.y,
                        w = self.title_height + 4,
                        h = self.title_height + 4},
                        GUI.mouse.x, GUI.mouse.y) then
        return true
    end
end


function GUI.Window:blitwindow()

    -- Copy the graphics buffer to use as a background for the window
    -- since everything is hidden
    gfx.dest = self.buffs[3]
    gfx.setimgdim(self.buffs[3], -1, -1)
    gfx.setimgdim(self.buffs[3], GUI.cur_w, GUI.cur_h)

    --gfx.blit(source, scale, rotation[, srcx, srcy, srself.close_width, srch, destx, desty, destw, desth, rotxoffs, rotyoffs] )
    gfx.blit(0, 1, 0, 0, 0, GUI.cur_w, GUI.cur_h, 0, 0, GUI.cur_w, GUI.cur_h)
    gfx.x, gfx.y = 0, 0
    gfx.blurto(GUI.cur_w, GUI.cur_h)

end


function GUI.Window:hidelayers()

    -- Store the actual hidden layers, and then hide everything...
    local elms_hide = {}
    for i = 1, GUI.z_max do
        if GUI.elms_hide[i] then elms_hide[i] = true end
        GUI.elms_hide[i] = true
    end
    self.elms_hide = elms_hide

    -- ...except the window and its child layers
    GUI.elms_hide[self.z] = false
    for k, v in pairs(self.z_set) do
        GUI.elms_hide[v] = false
    end

end


function GUI.Window:showlayers()

    -- Set the layer visibility back to where it was
    for i = 1, GUI.z_max do
        GUI.elms_hide[i] = self.elms_hide[i]
    end

    -- Hide the window and its child layers
    GUI.elms_hide[self.z] = true
    for k, v in pairs(self.z_set) do
        GUI.elms_hide[v] = true
    end

end


function GUI.Window:getchildelms()

    local elms = {}
    for _, n in pairs(self.z_set) do

        if GUI.elms_list[n] then
            for k, v in pairs(GUI.elms_list[n]) do
                if v ~= self.name then elms[v] = true end
            end
        end
    end

    return elms

end