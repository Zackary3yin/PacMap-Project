function step11_interactive_GUI
    %% 1. 加载 paCMAP 坐标和标签
    D = load(fullfile('GUI_results','AllCenters','pacmap_coords.mat'), ...
             'subject','idx_center','label','x','y');
    subjects    = D.subject;
    idx_centers = D.idx_center;
    labels      = D.label;
    X           = D.x;
    Y           = D.y;
    nPts        = numel(X);

    %% 2. 创建主 Figure 和坐标轴布局
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
    %xlabel(axScatter,'PaCMAP dim1'); ylabel(axScatter,'PaCMAP dim2');
    title(axScatter,'CP‐centers embedding');
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

    % 右侧：多通道 EEG (40% 宽度 × 90% 高度)
    axEEG = axes('Parent',hFig,'Position',[0.63 0.05 0.35 0.90]);
    title(axEEG,'Raw multi‐channel EEG + EKG');
    xlabel(axEEG,'Time (s)'); ylabel(axEEG,'Channels');

    % 下方显示点击点的机器标签
    hLabel = uicontrol(hFig,'Style','text','Units','normalized', ...
        'Position',[0.63 0.96 0.35 0.03],'FontSize',12, ...
        'HorizontalAlignment','left','String','Machine label: —');

    %% 3. 注册 datatip 点击回调
    pts = [X(:), Y(:)];
    dcm = datacursormode(hFig);
    set(dcm,'UpdateFcn',@onClick,'Enable','on');

    function txt = onClick(~,evt)
        pos = evt.Position;
        d2  = sum((pts - pos).^2,2);
        [~, idx] = min(d2);

        % 更新标签显示
        set(hLabel,'String',sprintf('Machine label: %s', labels{idx}));

        % 加载对应的 CP_center mat 文件
        subj = subjects{idx};
        ic   = idx_centers(idx);
        fname = sprintf('%s_%03d.mat', subj, ic);
        S = load(fullfile('GUI_results','AllCenters','CP_centers_all',fname), ...
                 'SEG','Sparsed','sfreqs');

        Fs = 100;
        t  = (0:size(S.SEG,2)-1)/Fs;

        % 在 3 个 spectrogram 轴上绘图
        for ch = 1:3
            axes(axSpec(ch)); cla;
            imagesc(axSpec(ch), pow2db(S.Sparsed{ch,2}),'XData',1:size(S.Sparsed{ch,2},2));
            axis(axSpec(ch),'xy');
            title(axSpec(ch),sprintf('Spectrogram Ch %d',ch));
        end

        % 在右侧多通道 EEG 轴上绘图
        axes(axEEG); cla; hold(axEEG,'on');
        nCh = size(S.SEG,1);                    % 应该是 20（19 EEG + EKG）
        offs = (nCh:-1:1)';                     % 便于垂直排列
        for ch = 1:nCh
            plot(axEEG, t, S.SEG(ch,:) + offs(ch)*50, 'k');  % 50 μV 间距
        end
        set(axEEG, 'YTick', offs*50, ...
                   'YTickLabel', [arrayfun(@(c) sprintf('Ch%02d',c),1:19,'uni',0), {'EKG'}], ...
                   'YLim',[0 (nCh+1)*50], 'Box','on');
        xlabel(axEEG,'Time (s)'); ylabel(axEEG,'Channel');
        hold(axEEG,'off');

        % data tip 文本
        txt = { sprintf('%s #%d', subj, ic), sprintf('Label: %s', labels{idx}) };
    end
end