%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step4_readMAT_and_pad_save_mat_multiCenter.m
% 多中心：外接硬盘读取 result/<center>/*.mat(含模型输出) → 对齐 EEG 窗口 → 保存到"当前脚本目录"
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略 ————
dataRoot = 'F:\ICARE_organized';                          %%% 修改：只读外接硬盘
projRoot = fileparts(mfilename('fullpath'));               %%% 修改：输出到当前脚本目录

% ———— 1) 中心列表（按需增/改）———
centers  = {'BIDMC','MGH','ULB'};                          %%% 修改：示例中心

% ———— 2) 采样率 ————
Fs = 100;  % Hz

for c = 1:numel(centers)
    center = centers{c};
    fprintf('🌐 正在处理中心: %s\n', center);

    % ———— 3) 输入/输出路径 ————
    eegDir = fullfile(dataRoot, 'eeg',    center);         %%% 修改：从外接硬盘读 EEG
    resDir = fullfile(dataRoot, 'result', center);         %%% 修改：从外接硬盘读 result(.mat)
    outDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction');  %%% 修改：写到脚本目录
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % ———— 4) 遍历 EEG 文件 ————
    eegFiles = dir(fullfile(eegDir, '*.mat'));
    nFiles   = numel(eegFiles);
    if nFiles == 0
        fprintf('⚠️  中心 %s 没有 EEG 文件，跳过\n\n', center);
        continue;
    end

    for i = 1:nFiles
        [~, name] = fileparts(eegFiles(i).name);

        % —— 4.1 读取 EEG 时长 → 2s 窗口数 mm ——
        info = whos('-file', fullfile(eegDir, eegFiles(i).name));
        M = [];
        try
            if ismember('data', {info.name})
                D = load(fullfile(eegDir, eegFiles(i).name), 'data');
                M = size(D.data, 2);
            elseif ismember('x', {info.name})
                X = load(fullfile(eegDir, eegFiles(i).name), 'x');
                if isstruct(X.x) && isfield(X.x, 'data')
                    M = size(X.x.data, 2);
                else
                    error('x 存在但不含 data 字段');
                end
            else
                error('未在 EEG mat 中找到 data 或 x.data');
            end
        catch ME
            warning('❌ EEG 读取失败 [%s]: %s，跳过', eegFiles(i).name, ME.message);
            continue;
        end
        mm = ceil(M / (2 * Fs));  % 2 秒一段

        % —— 4.2 读取 result/<center>/<name>_score.mat（MAT 而非 CSV）——
        inMat = fullfile(resDir, [name '_score.mat']);     %%% 修改：改为读取 MAT
        if ~isfile(inMat)
            warning('❌ 缺失 result MAT: %s，跳过', inMat);
            continue;
        end

        % —— 4.3 取出模型输出矩阵 ——（变量名优先级：Y_model > score > Y > Ycsv）
        try
            S = load(inMat);
        catch ME
            warning('❌ 加载失败: %s (%s)', inMat, ME.message);
            continue;
        end

        if     isfield(S, 'Y_model')                       %%% 修改：优先 Y_model
            Ycsv = S.Y_model;
        elseif isfield(S, 'score')
            Ycsv = S.score;
        elseif isfield(S, 'Y')
            Ycsv = S.Y;
        elseif isfield(S, 'Ycsv')
            Ycsv = S.Ycsv;
        else
            warning('❌ %s 中未找到 Y_model/score/Y/Ycsv，跳过', inMat);
            continue;
        end

        % —— 4.4 统一为数值矩阵（N×K）——
        if istable(Ycsv),   Ycsv = table2array(Ycsv); end
        if isvector(Ycsv),  Ycsv = Ycsv(:);          end
        if ~isnumeric(Ycsv)
            warning('❌ %s: 模型输出不是数值类型，跳过', inMat);
            continue;
        end
        if isempty(Ycsv)
            warning('❌ %s: 模型输出为空，跳过', inMat);
            continue;
        end

        % —— 4.5 前置两行 + 对齐 EEG 段数（截断/后填充）——
        Y = [repmat(Ycsv(1,:), 2, 1); Ycsv];        %%% 修改：逻辑保留，但明确来自 MAT
        nn = size(Y, 1);

        if nn > mm
            Y = Y(1:mm, :);                          % 截断
        elseif nn < mm
            Y = [Y; repmat(Y(end,:), mm - nn, 1)];   % 后填充
        end

        % —— 4.6 保存为 *_score.mat（变量名仍为 Y_model）——
        Y_model = Y; %#ok<NASGU>
        outMat  = fullfile(outDir, [name '_score.mat']);
        try
            save(outMat, 'Y_model', '-v7.3');
            fprintf('✅ (%2d/%2d) [%s] %s → %d rows → saved\n', i, nFiles, center, name, size(Y,1));
        catch ME
            warning('❌ 保存失败 %s: %s', outMat, ME.message);
        end
    end

    fprintf('✅ 中心 %s 处理完毕，共 %d 个文件\n\n', center, nFiles);
end