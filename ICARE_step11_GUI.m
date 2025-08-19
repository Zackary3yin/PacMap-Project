function step11_interactive_GUI
    %% 0) 根路径：以"脚本所在目录"为根  %%% 修改
    projRoot = fileparts(mfilename('fullpath'));                             %%% 修改
    pacmapMat = fullfile(projRoot,'GUI_results','AllCenters','pacmap_coords.mat');  %%% 修改
    cpcentersDir = fullfile(projRoot,'GUI_results','AllCenters','CP_centers_all');  %%% 修改

    if ~exist(pacmapMat,'file')
        error('未找到 PaCMAP 坐标：%s（请先运行 step10_plot_pacmap.py）', pacmapMat);
    end
    if ~exist(cpcentersDir,'dir')
        error('未找到 CP_centers_all 目录：%s（请先完成 step7）', cpcentersDir);
    end

    %% 1) 加载 paCMAP 坐标和标签
    D = load(pacmapMat, 'subject','idx_center','label','x','y');             %%% 修改：使用新根路径
    subjects    = D.subject;    % cell
    idx_centers = D.idx_center; % double
    labels      = D.label;      % cell
    X           = D.x;          % double
    Y           = D.y;          % double
    nPts        = numel(X);

    %% 2) 创建主 Figure 和坐标轴布局
    hFig = figure('Name','Interactive PaCMAP Explorer','Units','normalized',...
                  'Position',[.1 .1 .8 .8],'MenuBar','none','ToolBar','none');

    % 左上：scatter (55% 宽度 × 55% 高度)
    axScatter = axes('Parent',hFig,'Position',[0.05 0.45 0.55 0.50]);
    hold(axScatter,'on');
    ulab = unique(labels);
    cmap = lines(numel(ulab));
    for i=1:numel(ulab)
        mask = strcmp(labels,ulab{i});
        scatter(axScatter, X(mask), Y(mask), 20, ...
                'MarkerFaceColor',cmap(i,:), 'MarkerEdgeColor','k', ...
                'DisplayName',ulab{i});
    end
    legend(axScatter,'Location','eastoutside');
    xlabel(axScatter,'PaCMAP dim 1'); ylabel(axScatter,'PaCMAP dim 2');      %%% 修改：恢复坐标轴标题
    title(axScatter,'CP-centers embedding');
    grid(axScatter,'on');
    hold(axScatter,'off');

    % 左下：3×1 spectrograms 区域 (55% 宽度 × 40% 高度)
    specY = 0.05; specH = 0.35;
    axSpec = gobjects(3,1);
    for i=1:3
        axSpec(i) = axes('Parent',hFig, ...
            'Position',[0.05, specY+(3-i)*(specH/3), 0.55, specH/3-0.01]);
        title(axSpec(i),sprintf('Spectrogram Ch %d',i));
        ylabel(axSpec(i),'Freq bin'); xlabel(axSpec(i),'Time win');
        axis(axSpec(i),'off');
    end
    colormap(hFig,'parula');                                                  %%% 修改：统一配色

    % 右侧：多通道 EEG (40% 宽度 × 90% 高度)
    axEEG = axes('Parent',hFig,'Position',[0.63 0.05 0.35 0.90]);
    title(axEEG,'Raw multi-channel EEG + EKG');
    xlabel(axEEG,'Time (s)'); ylabel(axEEG,'Channels');

    % 下方显示点击点的机器标签
    hLabel = uicontrol(hFig,'Style','text','Units','normalized', ...
        'Position',[0.63 0.96 0.35 0.03],'FontSize',12, ...
        'HorizontalAlignment','left','String','Machine label: —');

    %% 3) 注册 datatip 点击回调
    pts = [X(:), Y(:)];
    dcm = datacursormode(hFig);
    set(dcm,'UpdateFcn',@onClick,'Enable','on');

    %%% 修改：增加 dB 转换的兼容函数句柄
    toDB = @(A) local_todb(A);                                               %%% 修改

    function txt = onClick(~,evt)
        pos = evt.Position;
        d2  = sum((pts - pos).^2,2);
        [~, idx] = min(d2);

        % 更新标签显示
        set(hLabel,'String',sprintf('Machine label: %s', labels{idx}));

        % 加载对应的 CP_center mat 文件（用脚本根路径）
        subj = subjects{idx};
        ic   = idx_centers(idx);
        fname = sprintf('%s_%03d.mat', subj, ic);
        fpath = fullfile(cpcentersDir, fname);                                %%% 修改：使用新根路径
        if ~exist(fpath,'file')
            warning('未找到样本文件：%s', fpath);
            txt = { sprintf('%s #%d', subj, ic), sprintf('Label: %s', labels{idx}), '(missing file)' };
            return;
        end

        S = load(fpath, 'SEG','Sparsed','sfreqs');
        if ~isfield(S,'SEG') || ~isfield(S,'Sparsed')
            warning('文件缺少 SEG/Sparsed：%s', fpath);
            txt = { sprintf('%s #%d', subj, ic), sprintf('Label: %s', labels{idx}), '(invalid file)' };
            return;
        end

        Fs = 100;
        t  = (0:size(S.SEG,2)-1)/Fs;

        % 在 3 个 spectrogram 轴上绘图：第 1~3 区域（若不足则按可用画）
        nView = min(3, size(S.Sparsed,1));
        for ch = 1:nView
            axes(axSpec(ch)); cla;
            if size(S.Sparsed,2) >= 2 && ~isempty(S.Sparsed{ch,2})
                spec2 = S.Sparsed{ch,2};
            else
                % 兜底：若第2列不存在，尝试第1列
                spec2 = S.Sparsed{ch,1};
            end
            imagesc(axSpec(ch), toDB(max(spec2, eps)));                       %%% 修改：稳健 dB 转换
            axis(axSpec(ch),'xy');
            title(axSpec(ch),sprintf('Spectrogram Ch %d',ch));
            xlabel(axSpec(ch),'Time win'); ylabel(axSpec(ch),'Freq bin');
        end
        for ch = nView+1:3
            axes(axSpec(ch)); cla; axis(axSpec(ch),'off');
        end

        % 在右侧多通道 EEG 轴上绘图
        axes(axEEG); cla; hold(axEEG,'on');
        nCh = size(S.SEG,1);                    % 通道数（通常 20：19 EEG + 1 EKG）
        offs = (nCh:-1:1)';                     % 便于垂直排列（上高下低）
        step = 50;                               % 50 μV 间距
        for ch = 1:nCh
            plot(axEEG, t, S.SEG(ch,:) + offs(ch)*step, 'k');
        end
        yticks = offs*step;
        % 标签：前 19 个为 EEG，最后一个为 EKG（若不足 20 也能自适应） %%% 修改：更健壮
        eegLabels = arrayfun(@(c) sprintf('Ch%02d',c), 1:max(0,nCh-1), 'uni', 0);
        if nCh >= 1, eegLabels{end+1} = 'EKG'; end
        set(axEEG, 'YTick', yticks, 'YTickLabel', eegLabels, ...
                   'YLim',[0 (nCh+1)*step], 'Box','on');
        xlabel(axEEG,'Time (s)'); ylabel(axEEG,'Channel');
        hold(axEEG,'off');

        % data tip 文本
        txt = { sprintf('%s #%d', subj, ic), sprintf('Label: %s', labels{idx}) };
    end
end

%% —— 本地函数：稳健 dB 转换，兼容无 Signal Toolbox 的环境 ——  %%% 修改
function Y = local_todb(X)
    X = double(X);
    X(~isfinite(X)) = 0;
    X = max(X, eps);
    try
        Y = pow2db(X);          % 若信号工具箱可用
    catch
        Y = 10*log10(X);        % 兜底：通用 dB
    end
end