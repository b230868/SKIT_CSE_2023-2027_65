import 'student_monitoring_detail.dart';
import 'student_monitoring_item.dart';

class MockStudentMonitoringData {
  static final List<StudentMonitoringItem> students = [
    StudentMonitoringItem(
      studentId: 'student-001',
      studentName: 'Demo Student 1',
      internshipId: 'internship-001',
      internshipTitle: 'Software Development Internship',
      applicationStatus: 'pending',
      studentEmail: 'student1@college.edu',
      rollNumber: '23CS001',
      department: 'Computer Science',
      batchYear: 2026,
      companyName: 'Tech Innovations Ltd',
      internshipStatus: 'active',
      itrStatus: 'submitted',
      hasCertificate: true,
      certificateStatus: 'pending',
      progress: 60,
      hasPendingApprovals: true,
    ),
    StudentMonitoringItem(
      studentId: 'student-002',
      studentName: 'Demo Student 2',
      internshipId: 'internship-002',
      internshipTitle: 'Data Analytics Internship',
      applicationStatus: 'approved',
      studentEmail: 'student2@college.edu',
      rollNumber: '23IT002',
      department: 'Information Technology',
      batchYear: 2026,
      companyName: 'DataSphere Analytics',
      internshipStatus: 'active',
      itrStatus: 'draft',
      hasCertificate: false,
      certificateStatus: null,
      progress: 35,
      hasPendingApprovals: false,
    ),
  ];

  static StudentMonitoringDetail getDetails(String studentId) {
    if (studentId == 'student-002') {
      return StudentMonitoringDetail(
        studentId: 'student-002',
        studentName: 'Demo Student 2',
        studentEmail: 'student2@college.edu',
        rollNumber: '23IT002',
        department: 'Information Technology',
        branch: 'Information Technology',
        batchYear: 2026,
        phone: '+91 9876543211',
        address: 'Sector 5, Salt Lake, Kolkata',
        internshipId: 'internship-002',
        internshipTitle: 'Data Analytics Internship',
        companyName: 'DataSphere Analytics',
        internshipMode: 'hybrid',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 11, 30),
        internshipStatus: 'active',
        progress: 35,
        description:
            'Analyzing performance metrics and building predictive models.',
        industryName: 'DataSphere Analytics',
        industryAddress: 'Plot 14, Electronic Complex, Kolkata',
        industryEmail: 'hr@datasphere.com',
        industryPhone: '+91 33 2345 6789',
        itrId: 'itr-002',
        itrStatus: 'draft',
        itrProjectTitle: 'Customer Churn Analytics Pipeline',
        itrWorkDone:
            'Data ingestion and exploratory data analysis using Python pandas.',
        itrTechnologiesUsed: 'Python, Pandas, Scikit-learn, SQL',
        itrKeyLearnings: 'Hands-on exposure to production data warehousing.',
        itrChallengesFaced:
            'Handling sparse categorical data in legacy extracts.',
        itrSubmittedAt: null,
        certificateId: null,
        certificateFilePath: null,
        certificateStatus: null,
        approvalReviews: [
          StudentApprovalReviewItem(
            id: 'rev-002',
            reviewStage: 'faculty',
            status: 'approved',
            remarks: 'Internship scope confirmed by faculty mentor.',
            createdAt: DateTime(2026, 8, 5),
          ),
        ],
      );
    }

    return StudentMonitoringDetail(
      studentId: 'student-001',
      studentName: 'Demo Student 1',
      studentEmail: 'student1@college.edu',
      rollNumber: '23CS001',
      department: 'Computer Science',
      branch: 'Computer Science & Engineering',
      batchYear: 2026,
      phone: '+91 9876543210',
      address: 'Jaipur, Rajasthan',
      internshipId: 'internship-001',
      internshipTitle: 'Software Development Internship',
      companyName: 'Tech Innovations Ltd',
      internshipMode: 'onsite',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 10, 31),
      internshipStatus: 'active',
      progress: 60,
      description:
          'Developing Flutter applications and integrating RESTful APIs.',
      industryName: 'Tech Innovations Ltd',
      industryAddress: 'Cyber City, Jaipur',
      industryEmail: 'contact@techinnovations.com',
      industryPhone: '+91 141 2345678',
      itrId: 'itr-001',
      itrStatus: 'submitted',
      itrProjectTitle: 'Mobile ERP & Monitoring Solution',
      itrWorkDone:
          'Built offline caching and Supabase synchronization modules.',
      itrTechnologiesUsed: 'Flutter, Dart, Supabase, Hive',
      itrKeyLearnings:
          'Mobile state management, RLS policies, automated CI/CD.',
      itrChallengesFaced: 'Managing concurrency and network retry policies.',
      itrDocumentPath: 'itrs/student-001/itr_report.pdf',
      itrProjectZipPath: 'itrs/student-001/project_code.zip',
      itrSubmittedAt: DateTime(2026, 9, 20),
      itrReviewedAt: null,
      itrReviewerName: 'Prof. Sharma',
      itrRemarks:
          'Good progress reported. Ensure test documentation is attached.',
      certificateId: 'cert-001',
      certificateFilePath: 'certificates/student-001/completion_cert.pdf',
      certificateStatus: 'pending',
      certificateCreatedAt: DateTime(2026, 10, 1),
      approvalReviews: [
        StudentApprovalReviewItem(
          id: 'rev-001',
          reviewStage: 'faculty',
          status: 'approved',
          remarks: 'Approved by faculty mentor.',
          createdAt: DateTime(2026, 7, 5),
        ),
        StudentApprovalReviewItem(
          id: 'rev-002',
          reviewStage: 'tp_admin',
          status: 'pending',
          remarks: 'Under review by Training & Placement cell.',
          createdAt: DateTime(2026, 7, 6),
        ),
      ],
    );
  }
}
