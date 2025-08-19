%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step7_parseData_cp_centers_allCenters_withFeat.m
% 说明：多中心融合版——针对所有中心，解析每个 CP center 的 EEG、
%      频谱图、模型概率 + 对应的 28 维特征，并统一保存到一个全局目录中。
%      输出文件以 "ICARE_ID_IDX.mat" 命名，不含中心名和日期，只保留被试 ID 和 CP 索引。
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% 0. 路径策略
dataRoot = 'F:\ICARE_organized';                                   %%% 修改：外接硬盘数据根（只读，仅用于 EEG）
projRoot = fileparts(mfilename('fullpath'));                        %%% 修改：当前脚本目录（Tools/GUI_results/输出）

% 1. 加工具函数路径
addpath(genpath(fullfile(projRoot,'Tools')));                       %%% 修改：Tools 放在脚本目录

% 2. 中心列表
centers = {'BIDMC','MGH','ULB'};                                    %%% 修改：按你的数据更新

% 3. 通用参数
Fs     = 100;   % EEG 采样率 (Hz)
ww_eeg = 14;    % EEG 片段长度 (秒)
ww_spe = 300;   % 谱图窗口数 (2s 单位，即 10min)

% 4. 全局输出目录（脚本目录下）
allOutDir = fullfile(projRoot,'GUI_results','AllCenters','CP_centers_all');  %%% 修改：输出到脚本目录
if ~exist(allOutDir,'dir'); mkdir(allOutDir); end

% 5. 遍历每个中心
for ci = 1:numel(centers)
    center = centers{ci};
    fprintf('=== Processing center: %s ===\n', center);

    % 5.1 构建各子目录路径
    cpcDir    = fullfile(projRoot,'GUI_results', center,'CPDs1');                         %%% 修改
    speDir    = fullfile(projRoot,'GUI_results', center,'Spectrograms1');                  %%% 修改
    scoreDir  = fullfile(projRoot,'GUI_results', center,'model_prediction');               %%% 修改
    featDir   = fullfile(projRoot,'GUI_results', center,'model_prediction','model_prediction_fet_s'); %%% 修改
    dataDir   = fullfile(dataRoot,'eeg', center);                                          %%% 修改：EEG 只读外接硬盘

    % 5.2 列出该中心所有 EEG 原始文件
    eegFiles = dir(fullfile(dataDir,'*.mat'));
    if isempty(eegFiles)
        warning('⚠️ Center %s: No EEG files found in %s, skip.', center, dataDir);
        continue;
    end

    % 5.3 遍历每个患者文件
    for i = 1:numel(eegFiles)
        fullName = eegFiles(i).name;           % ICARE_0015_20150416_104509.mat
        fileKey  = fullName(1:end-4);          % ICARE_0015_20150416_104509
        fprintf('  [%d/%d] %s\n', i, numel(eegFiles), fileKey);

        % 5.3.1 提取被试 ID（去掉日期，保留前两段）
        parts = split(fileKey,'_');
        if numel(parts) < 3
            warning('  文件名不符合惯例(期望 ICARE_xxxx_YYYYMMDD_HHMMSS)：%s，跳过', fullName);
            continue;
        end
        subjectID = strjoin(parts(1:2),'_');   % ICARE_0015

        % 5.3.2 读特征矩阵 Xlogit_cpd（来自 step6_4 的输出）
        featFile = fullfile(featDir, [subjectID '.mat']);
        if ~exist(featFile,'file')
            warning('    Missing feature file: %s, skip features.', featFile);
            Xlogit_cpd = [];
        else
            tmpF = load(featFile, 'Xlogit_cpd');
            if isfield(tmpF,'Xlogit_cpd')
                Xlogit_cpd = tmpF.Xlogit_cpd;  % 形状 ~ [nCP_centers × d]
            else
                warning('    %s 中缺少 Xlogit_cpd，feat_row 将置 NaN。', featFile);
                Xlogit_cpd = [];
            end
        end

        % 5.3.3 加载 CPD 查表
        cpcPath = fullfile(cpcDir, [fileKey '_cpc.mat']);
        if ~exist(cpcPath,'file')
            warning('    Missing CPD file: %s, skip.', cpcPath);
            continue;
        end
        C = load(cpcPath,'lut_cpd','isCPcenters','isCPs');  % 读多点以便调试
        if ~isfield(C,'lut_cpd')
            warning('    %s 缺少 lut_cpd，跳过。', cpcPath); 
            continue;
        end
        lut = C.lut_cpd;                    % [m × 3] 三列：中心索引、起、止
        if size(lut,2) < 3 || isempty(lut)
            warning('    %s: lut_cpd 为空或列不足，跳过。', cpcPath);
            continue;
        end

        % 5.3.4 加载模型预测（step4 的输出）
        scorePath = fullfile(scoreDir, [fileKey '_score.mat']);
        if ~exist(scorePath,'file')
            warning('    Missing score file: %s, skip.', scorePath);
            continue;
        end
        Sscore = load(scorePath);
        if     isfield(Sscore,'Y_model')
            Ymodel = Sscore.Y_model;
        elseif isfield(Sscore,'score')
            Ymodel = Sscore.score;
        elseif isfield(Sscore,'Y')
            Ymodel = Sscore.Y;
        elseif isfield(Sscore,'Ycsv')
            Ymodel = Sscore.Ycsv;
        else
            warning('    %s 中未找到 Y_model/score/Y/Ycsv，跳过。', scorePath);
            continue;
        end

        % 5.3.5 加载谱图（step5 的输出）
        spePath = fullfile(speDir, [fileKey '_spect.mat']);
        if ~exist(spePath,'file')
            warning('    Missing spect file: %s, skip.', spePath);
            continue;
        end
        Sspe = load(spePath,'Sdata','sfreqs');
        if ~isfield(Sspe,'Sdata') || ~isfield(Sspe,'sfreqs')
            warning('    %s 缺少 Sdata/sfreqs，跳过。', spePath);
            continue;
        end
        SDATA  = Sspe.Sdata;                % cell 数组，{ch,2}=matrix
        sfreqs = Sspe.sfreqs;               % 频率向量
        if isempty(SDATA) || size(SDATA,2) < 2 || isempty(SDATA{1,2})
            warning('    %s 的 Sdata 结构异常，跳过。', spePath);
            continue;
        end
        Mwin   = size(SDATA{1,2}, 2);
        nFreqs = size(SDATA{1,2}, 1);

        % 5.3.6 加载原始 EEG（只读外接硬盘）
        Efile = fullfile(dataDir, [fileKey '.mat']);
        if ~exist(Efile,'file')
            warning('    EEG file missing: %s，跳过。', Efile);
            continue;
        end
        Ex = load(Efile);
        if isfield(Ex,'data')
            data = Ex.data;
        elseif isfield(Ex,'x') && isfield(Ex.x,'data')
            data = Ex.x.data;
        else
            warning('    %s 中未找到 data 或 x.data，跳过。', Efile);
            continue;
        end
        [nCh, N] = size(data);

        % 5.3.7 对每个 CP center 提取并保存
        for kk = 1:size(lut,1)
            idx_center = lut(kk,1);        % 中心窗口索引
            idx_range  = lut(kk,2:3);      % [start, end]

            % —— 概率行保护 —— 
            if idx_center < 1 || idx_center > size(Ymodel,1)
                warning('    idx_center=%d 超出 Ymodel 行数(%d)，跳过该条。', idx_center, size(Ymodel,1));
                continue;
            end
            scores = Ymodel(idx_center,:);

            % —— 28-dim 特征行（来自 step6_4 的 Xlogit_cpd）——
            if ~isempty(Xlogit_cpd) && idx_center <= size(Xlogit_cpd,1)
                feat_row = Xlogit_cpd(idx_center,:);
            else
                feat_row = nan(1, max(1, size(Xlogit_cpd,2)));  %#ok<NASGU>
            end

            % 新文件名：ICARE_ID_IDX.mat
            outName = sprintf('%s_%03d.mat', subjectID, idx_center);
            outPath = fullfile(allOutDir, outName);

            % (A) 14s EEG 段
            t_c   = idx_center*2 - 1;                % 以 2s 窗为单位的中心 → 秒
            halfE = (ww_eeg/2)*Fs;
            left  = max(1, round(t_c*Fs - halfE));
            right = min(N, round(t_c*Fs + halfE));
            if right < left
                warning('    EEG 窗口索引异常(left>right)，跳过 %s_%d。', subjectID, idx_center);
                continue;
            end
            seg_eeg = data(:, left:right);
            SEG     = fcn_parseData([nCh,N], seg_eeg, Fs, left, right, ww_eeg);

            % (B) 谱图 10min 片段（以 2s 窗口计数）
            halfS = floor(ww_spe/2);
            sl    = max(1, idx_center - halfS);
            sr    = min(Mwin, idx_center + halfS);
            if sr < sl
                warning('    谱图窗口索引异常(sl>sr)，跳过 %s_%d。', subjectID, idx_center);
                continue;
            end
            Sparsed = SDATA;
            for ch = 1:size(Sparsed,1)
                mat0 = SDATA{ch,2}(:, sl:sr);
                Sparsed{ch,2} = fcn_parseData([nFreqs, Mwin], mat0, 1, sl, sr, ww_spe);
            end

            % —— 保存所有变量，包括 feat_row —— 
            save(outPath, 'SEG', 'Sparsed', 'sfreqs', ...
                          'scores','idx_range','idx_center', ...
                          'feat_row');   % <--- 28 维特征
            fprintf('    Saved: %s (incl. feat_row)\n', outName);
        end
    end
end

fprintf('====== All centers parsed and merged into %s ======\n', allOutDir);