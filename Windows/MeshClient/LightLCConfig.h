#pragma once


// CLightLcConfig dialog

class CLightLcConfig : public CDialogEx
{
	DECLARE_DYNAMIC(CLightLcConfig)

public:
	CLightLcConfig(CWnd* pParent = nullptr);   // standard constructor
	virtual ~CLightLcConfig();

    char component_name[80];
    void PropertyStatus(int property_id, int value);
    // Dialog Data
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_LC_CONFIG };
#endif

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support

	DECLARE_MESSAGE_MAP()
public:
    afx_msg void OnBnClickedLightLcPropertyGet();
    afx_msg void OnBnClickedLightLcPropertySet();
    virtual BOOL OnInitDialog();
    afx_msg void OnBnClickedLightLcModeGet();
    afx_msg void OnBnClickedLightLcOccupancyModeGet();
    afx_msg void OnBnClickedLightLcOnOffGet();
    afx_msg void OnBnClickedLightLcModeSetOn();
    afx_msg void OnBnClickedLightLcModeSetOff();
    afx_msg void OnBnClickedLightLcOccupancyModeSetOn();
    afx_msg void OnBnClickedLightLcOccupancyModeSetOff();
    afx_msg void OnBnClickedLightLcSetOn();
    afx_msg void OnBnClickedLightLcSetOff();
};
