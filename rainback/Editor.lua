require "fritomod/Strings";
require "fritomod/Lists";
require "fritomod/Frames-Position";
require "fritomod/LuaEnvironment";
require "rainback/ScriptPage";
require "fritomod/Serializers-Data";

UI = UI or {};
UI.Editor = OOP.Class();
local Editor = UI.Editor;

local WIDTH = 500;
local HEIGHT = 550;

function Editor:Constructor(parent)
	parent = Frames.AsRegion(parent);
	assert(parent, "Parent frame must be provided");
	assert(parent.CreateTexture, "Provided parent must be a real frame");

    self.editor = Rainback.TextEdit();
    self.editor.tabStopWidth = 30;
    self.editor.styleSheet = [[
        font-family: Consolas, Inconsolata, monospace;
        font-size: 13px;
        color: black;
        border: 1px solid black;
        border-top: none;
    ]];
    self.listWidth = 100; -- default width of the lists on the left

    self.title = Frames.New(parent, "Texture");
    Frames.WH(self.title, WIDTH + self.listWidth, 20);
    Frames.Color(self.title, "grey");

    self.menubar = Frames.New(parent, "Texture");
    Frames.Color(self.menubar, "gray");
    Frames.WH(self.menubar,WIDTH, 20);
    Anchors.VFlip(self.menubar, self.title, "bottomright");

    self.commandFrame = Frames.New(parent, "Widget");
    Anchors.VFlip(self.commandFrame, self.menubar, "bottomleft");
    Anchors.VFlip(self.commandFrame, self.menubar, "bottomright");

    self.command = Rainback.LineEdit();
    self.command.styleSheet = [[
        background: rgb(255, 255, 245);
        color: black;
        border: 1px solid grey;
        border-top: none;
        font-family: Consolas, Inconsolata, monospace;
    ]];
    self.commandFrame:SetWidget(self.command);

    self.editorFrame = Frames.New(parent, "Widget");
    Frames.Height(self.editorFrame, HEIGHT);
    Anchors.VFlipFromTop(self.editorFrame, self.commandFrame);
    self.editorFrame:SetWidget(self.editor);

    local run = Frames.Text(self.menubar, "default", 10);
    Frames.Color(run, "white");
    run:SetText("Run");
    Callbacks.Click(run, self, "Run");

    local reset = Frames.Text(self.menubar, "default", 10);
    Frames.Color(reset, "white");
    reset:SetText("Reset");
    Callbacks.Click(reset, self, "Reset");

    local publish = Frames.Text(self.menubar, "default", 10);
    Frames.Color(publish, "white");
    publish:SetText("Publish");
    Callbacks.Click(publish, self, "Publish");

    local sync = Frames.Text(self.menubar, "default", 10);
    Frames.Color(sync, "green");
    sync:SetText("Syncing");
    Callbacks.Click(sync, self, "ToggleSync");
    self.syncButton = sync;

    local links = {publish, sync, run, reset};
    Anchors.Share(Anchors.HJustify("right", 6, links), "right", self.menubar, 2);

    local scriptName = Frames.Text(self.menubar, "default", 10);
    Frames.Color(scriptName, "white");
    scriptName:SetText("<untitled>");
    Anchors.Share(scriptName, self.menubar, "left", 3, 3);

    function Editor:SetName(name)
        scriptName:SetText(name or "<untitled>");
    end;

    self.commands = {};

    self.command:connect("returnPressed", function()
        local cmd = self.command.text;
        local remover = self:AddCommand(cmd);
        if not remover then
            return;
        end;
        self.command.text = "";
    end);
end;

function Editor:LayoutCommands()
    Anchors.Clear(self.editorFrame);
    if #self.commands == 0 then
        Anchors.VFlipFromTop(self.editorFrame, self.commandFrame);
        return;
    end;
    Anchors.Clear(self.commands);
    Anchors.VFlip(Anchors.VJustifyFrom("bottomleft", -1, self.commands), "bottomleft", self.commandFrame, -1);
    Anchors.VFlipFromTop(self.editorFrame, self.commands[#self.commands]);
end;

function Editor:BuildCommand(command)
    local asset = Frames.New(parent);
    Frames.Color(asset, "blue", .2);
    Frames.WH(asset, WIDTH, 20);

    local assetText = Frames.Text(asset, "Inconsolata", 10);
    assetText:SetText(command);
    Anchors.Share(assetText, "left", 5);

    local close = Frames.Text(asset, "default", 8);
    close:SetText("Remove");
    Anchors.Share(close, asset, "right", 3);
    Callbacks.Click(close, function()
        self.page:RemoveCommand(command);
        Frames.Destroy(asset);
        Lists.Remove(self.commands, asset);

        self:LayoutCommands();
    end);
    return asset;
end;

function Editor:AddCommand(command)
    local result = self.page:AddCommand(command);
    if not result then
        return false;
    end;

    if not IsCallable(result) then
        return true;
    end;

    local ui = self:BuildCommand(command);
    table.insert(self.commands, ui);

    self:LayoutCommands();
    return true;
end;

function Editor:SetPage(page)
    self:Clear();
    self.page = page;
    if not self.page then
        return;
    end;

    self.editor.plainText = self.page:GetContent();
    self:SetName(self.page:GetName());

    local commands = self.page:GetCommands();
    for i=1, #commands do
        local ui = self:BuildCommand(commands[i]);
        table.insert(self.commands, ui);
    end;
    self:LayoutCommands();

    self.scriptRemover = Seal(Lists.CallEach, {
        function()
            Frames.Color(self.menubar, "grey");
        end,
        self.editor:connect("textChanged", function()
            if self.page then
                self.page:SetContent(self.editor.plainText);
            end;
        end),
        self.page:OnUpdate(function()
            self:SetName(self.page:GetName());

            local content = self.page:GetContent();
            if self.editor.plainText == content then
                return;
            end;
            self.editor.plainText = content;
        end)
    });
end;

function Editor:GetPage()
    return self.page;
end;

function Editor:Run(...)
    local success, rv = xpcall(
        Curry(self.page, "Run", ...),
        traceback
    );
    if success then
        Frames.Color(self.title, 0, .5, 0);
    else
        Frames.Color(self.title, "orange");
        print(rv);
    end;
end;

function Editor:Reset()
    local success, rv = xpcall(
        Curry(self.page, "Reset"),
        traceback
    );
    if success then
        Frames.Color(self.title, "grey");
    else
        Frames.Color(self.title, "orange");
        print(rv);
    end;
end;

local function Send(...)
    Remote:Send("rainback.Editor", Serializers.WriteData(...));
end;

function Editor:Publish()
    Send("Publish",
        self.page:GetName(),
        self.page:GetContent(),
        self.page:GetCommands()
    );
end;

function Editor:ToggleSync()
    if self:IsSynced() then
        self.page:StopSync();
        self.syncButton:SetText("Unsynced");
        Frames.Color(self.syncButton, "red");
    else
        self.page:Sync();
        self.syncButton:SetText("Syncing");
        Frames.Color(self.syncButton, "green");
    end;
end;

function Editor:IsSynced()
    return self.page:IsSynced();
end;

function Editor:Clear()
    if self.scriptRemover then
        self.scriptRemover();
        self.scriptRemover = nil;
    end;
    self.editor.plainText = "";
    self:SetName("<None>");
    if #self.commands > 0 then
        Frames.Destroy(self.commands);
    end;
    self.commands = {};
end;

function Editor:Handle()
    return self.title;
end;

function Editor:Destroy()
    self:Clear();
    Frames.Destroy(
       	self.menubar, 
        self.title,
        self.editorFrame
    );
    Editor.super.Destroy(self);
end;
