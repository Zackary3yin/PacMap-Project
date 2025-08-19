%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step5_compute_spectrograms_multiCenter.m
% 多中心模式：为每个中心计算多谱线谱图并保存
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略 ————
dataRoot = 'F:\ICARE_organized';                          %%% 修改：外接硬盘数据根（只读）
projRoot = fileparts(mfilename('fullpath'));               %%% 修改：当前脚本目录（写入与工具）

% ———— 1) 定义中心列表 ————
centers = {'BIDMC', 'MGH', 'ULB'};                         %%% 修改：示例中心，按需增减

% ———— 1.1) 添加 qEEG 工具箱路径（放在当前脚本目录的 Tools\qEEG 下）———
qEEGtool = fullfile(projRoot, 'Tools', 'qEEG');            %%% 修改：工具在脚本目录
addpath(genpath(qEEGtool));                                %%% 修改：确保 fcn_Bipolar / fcn_computeSpec 可见

% ———— 2) 设置谱图参数 ————
Fs = 100;
params.movingwin = [4, 2];        % 窗长 4s，步长 2s
params.tapers    = [2, 3];        % Taper 参数
params.fpass     = [0.5, 20];     % 频段
params.Fs        = Fs;

% ———— 3) 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('🌐 正在处理中心: %s\n', center);

    % —— 输入：外接硬盘；输出：脚本目录 ——
    dataDir = fullfile(dataRoot, 'eeg', center);                               %%% 修改：只读外接硬盘
    outDir  = fullfile(projRoot, 'GUI_results', center, 'Spectrograms1');      %%% 修改：写到脚本目录
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % 获取 EEG 文件列表
    eegFiles = dir(fullfile(dataDir, '*.mat'));
    if isempty(eegFiles)
        fprintf('⚠️  中心 %s 无 EEG 文件，跳过\n\n', center);
        continue;
    end

    % 遍历每个 EEG 文件
    for i = 1:numel(eegFiles)
        [~, name] = fileparts(eegFiles(i).name);

        % 加载 EEG 数据
        S = load(fullfile(dataDir, eegFiles(i).name));
        if isfield(S, 'data')
            raw = S.data;
        elseif isfield(S, 'x') && isfield(S.x, 'data')                         %%% 修改：更健壮的 x 检查
            raw = S.x.data;
        else
            warning('❌ 无法识别 EEG 文件变量: %s，跳过', name);
            continue;
        end
        raw(isnan(raw)) = 0;

        % 取前19通道并转为双极导联
        if size(raw,1) < 19                                                    %%% 修改：安全检查
            warning('⚠️ 通道数不足19(%d)：%s，按可用通道处理', size(raw,1), name);
            useCh = min(19, size(raw,1));
        else
            useCh = 19;
        end
        eeg_bi = fcn_Bipolar(raw(1:useCh, :));                                 %%% 修改：支持不足19通道

        % 计算谱图
        [Sdata, stimes, sfreqs] = fcn_computeSpec(eeg_bi, params);
        stimes = round(stimes);

        % 保存谱图结果
        specFile = fullfile(outDir, [name '_spect.mat']);
        save(specFile, 'Sdata', 'stimes', 'sfreqs', 'params', '-v7.3');
        fprintf('✅ (%2d/%2d) [%s] 计算完成: %s\n', i, numel(eegFiles), center, name);
    end

    fprintf('✅ 中心 %s 处理完毕，共处理 %d 个文件\n\n', center, numel(eegFiles));
end