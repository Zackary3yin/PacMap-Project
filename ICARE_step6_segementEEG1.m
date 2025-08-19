%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_0_segmentEEG_CPD_multiCenter.m
% 多中心模式：对所有中心执行变化点检测并保存 CPD 结果
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略 ————
dataRoot = 'F:\ICARE_organized';                       %%% 修改：外接硬盘根目录（只读）
projRoot = fileparts(mfilename('fullpath'));            %%% 修改：当前脚本目录（谱图读取 & 结果写入 & 工具）

% ———— 1) 中心列表 ————
centers = {'BIDMC','MGH','ULB'};                        %%% 修改：示例中心，按需增减

% 恢复 MATLAB 默认路径并添加工具路径
restoredefaultpath;
addpath(fullfile(projRoot, 'Tools'));                   %%% 修改：Tools 在脚本目录
addpath(fullfile(projRoot, 'Tools', 'qEEG'));           %%% 修改：qEEG 在脚本目录

% 检查必要函数是否存在
assert(~isempty(which('fcn_cpd')),        '❌ 缺失 fcn_cpd');
assert(~isempty(which('fcn_computeSpec')),'❌ 缺失 fcn_computeSpec');

% ———— 2) CPD 参数 ————
Fs = 100;           % 采样率 Hz
alpha_cpd = 0.1;    % CPD 灵敏度

% ———— 3) 遍历所有中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    % —— 输入/输出路径：读外接硬盘EEG；读脚本目录谱图；写脚本目录CPDs ——
    dataDir = fullfile(dataRoot, 'eeg', center);                             %%% 修改
    specDir = fullfile(projRoot, 'GUI_results', center, 'Spectrograms1');    %%% 修改
    outDir  = fullfile(projRoot, 'GUI_results', center, 'CPDs1');            %%% 修改
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    eegFiles = dir(fullfile(dataDir, '*.mat'));
    if isempty(eegFiles)
        fprintf('⚠️  中心 %s 无 EEG 文件，跳过\n', center);
        continue;
    end

    % 遍历该中心所有 EEG 文件
    for i = 1:numel(eegFiles)
        fileName = eegFiles(i).name;
        base = fileName(1:end-4);
        fprintf('(%d/%d) [%s] 处理文件: %s\n', i, numel(eegFiles), center, fileName);

        % —— 3.1 读取 EEG 长度（兼容 data 或 x.data） ——
        M = [];
        try
            info = whos('-file', fullfile(dataDir, fileName));
            if ismember('data', {info.name})
                Sx = load(fullfile(dataDir, fileName), 'data');
                M  = size(Sx.data, 2);
            elseif ismember('x', {info.name})
                Sx = load(fullfile(dataDir, fileName), 'x');
                if isstruct(Sx.x) && isfield(Sx.x, 'data')
                    M = size(Sx.x.data, 2);
                else
                    error('x 存在但无 data 字段');
                end
            else
                error('未检测到 data 或 x 变量');
            end
        catch ME
            warning('❌ EEG 读取失败: %s（%s）→ 跳过', fileName, ME.message);
            continue;
        end
        nn = ceil(M / (2 * Fs));  % 每 2 秒为一个窗口

        % —— 3.2 加载谱图并对齐长度 ——
        specPath = fullfile(specDir, [base '_spect.mat']);  %%% 修改：从脚本目录读取谱图
        if ~exist(specPath, 'file')
            warning('❌ 缺少谱图文件，跳过: %s', specPath);
            continue;
        end

        tmp = load(specPath, 'Sdata');
        if ~isfield(tmp, 'Sdata')
            warning('❌ %s 中没有 Sdata，跳过', specPath);
            continue;
        end

        % 取第二个区域谱图（与你原逻辑一致）
        Sdata = tmp.Sdata(:, 2);

        % 将所有区域谱图长度对齐到 nn（不足补零，超出截断）
        mm = size(Sdata{1}, 2);
        if mm >= nn
            for kk = 1:numel(Sdata)
                Sdata{kk} = Sdata{kk}(:, 1:nn);
            end
        else
            dd1 = size(Sdata{1}, 1);
            dd2 = nn - mm;
            for kk = 1:numel(Sdata)
                Sdata{kk} = [Sdata{kk}, zeros(dd1, dd2)];
            end
        end

        % —— 3.3 变化点检测 ——
        [isCPs, isCPcenters] = fcn_cpd(Sdata, alpha_cpd);

        % —— 3.4 构建 LUT（与原逻辑一致） ——
        idx_rise = find(isCPs);
        if isempty(idx_rise)
            lut_cpd = [1, 1, nn];
            isCPs = false(1, nn);
            isCPcenters = false(1, nn);
        else
            idx_fall = unique([idx_rise(2:end)-1; nn]);
            idx_cpc  = idx_rise(:);
            m = numel(idx_rise);
            idx_fall = idx_fall(1:m);
            lut_cpd  = [idx_cpc, idx_rise(:), idx_fall];
        end

        % —— 3.5 保存输出（到脚本目录） ——
        save(fullfile(outDir, [base '_cpc.mat']), 'isCPs', 'isCPcenters', 'lut_cpd', '-v7.3');
    end

    fprintf('✅ 中心 %s 完成 %d 个文件处理\n', center, numel(eegFiles));
end